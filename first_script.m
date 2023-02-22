%% Problem Description 
% This is so far strictly scheduling problem, demand charge would be 
% consider later.
% Flexible power considered 
% Pgrid >= 0 only

% Convention: if power is drawn from the element, then it assumes 
%   * positive value (hence, P_PV≥0 always)
%   * Row represents time step & columns represents vehicles 

% Ideas: 
%   1. Use the Simple Scheduler as the initial start
%   2. Use assign for initial guess
%   3. Play with the horizon time to reduce the number of variables
%   (horizon ends at the last planned departure time)
%   4. Sort the vehicles according to charging power 
%   5. Solve the problem with a very high demand -> initial solution /
%       heuristic peak (50% of the peak of this relaxed solution)
%   6. Treating this as a constrained optimization problem, refer to 
%       [ORTOOL](https://developers.google.com/optimization/cp/)
%       1. Use this feasible solution as initial solution for the MILP to
%       find the optimal solution

% TODO: 
%   1. Why adding +sum(ev) in the objective function solves a lot quicker
%         A: possibly since we force them to be 0 initially
%   2. Why are the EV charged during On Peak if we have surplus PV?    
%   3. Test Scenarios: Shortage of PV, Comparable PV and EV Load
clc
clear
yalmip('clear')
annualPv = readtimetable('PV_CA.csv');

%% Parameters

timeStep = 900;     % sec
horizonHours = 15;  % hour
nSockets = 10;  % Nbr of Sockets of Chargers = Nbr of Vehicles considered.
nTimeStepHourly = 3600 / timeStep;      % Number of time step per hour 
nTimeStep = horizonHours * nTimeStepHourly;     % Horizon length (timesteps)
startTime = 6;       % The horizon starts at 6am
bigM = 1e6; 

socMin = 0.01;
socMax = 0.99;
efficiencyCharging = 0.85 * ones(1, nSockets);
pCharging = sort(randi([18, 25], [1, nSockets]), 'descend');       % Max Charging Power of EVs [kW]
pDischarging = 0.9 * pCharging; % Max Discharging power of EVs [kW]
cEV = 4 * pCharging;                    % Assuming battery of 4h (kWh)

%% Input Data (to be updated)
%   1. tArrival(s) would be the number of time steps since the beginning of 
%       the horizon. To be updated every time step. 
%       Same for tDue & tDeparture 
%   2. Assume the horizon starts from 6 am

% Input from users 
tArrival = nTimeStepHourly * randi([2, 5], 1, nSockets);    % Arrival Time
tDeparture = nTimeStepHourly * randi([10, 14], 1, nSockets);    % Departure Time
socInit = socMin + (0.5 * socMax - socMin) * rand(1, nSockets);    % init Soc between socMin & socMax
socDesired = 0.9 * ones(1, nSockets);
tardinessCost = 150 * ones(1, nSockets);

% Profiles 
data.pPV = -0.1 * processPowerProfile( ...
    annualPv, datetime('2022-06-01') + hours(startTime), ...
    horizonHours, timeStep ...
    );      % kW 
data.pLoad = - 0.5 * max(data.pPV) * ones(nTimeStep, 1);   % kW
data.pNetLoad = data.pPV + data.pLoad; 
data.peakDemand = 0.25 * sum(pCharging) * ones(nTimeStep, 1); 
data.energyBuyPrice = 1 * (1 / nTimeStepHourly) * ones(nTimeStep, 1);
data.energySellPrice = 0 * (1 / nTimeStepHourly) * ones(nTimeStep, 1);
data.demandBuyPrice = dataGenerators( ...
    'demand', startTime, [12, 15], timeStep, horizonHours ...
    );

%% Problem Formulation - Variables

% Vehicles
ev = binvar(nTimeStep, nSockets, 'full');   % ev(v, t) = 1 if ev number v is charged at time t, 0 otherwise 
pVehicle = sdpvar(nTimeStep, nSockets, 'full');     % Power for charging Vehicles 
socVehicle = sdpvar(nTimeStep, nSockets, 'full');   % SoC for Vehicles 
socUnderChargedPos = sdpvar(1, nSockets);  % Positive soc over socDesired at departure
socUnderChargedNeg = sdpvar(1, nSockets);  % Negative soc over socDesired at departure

% Grid
pGrid = sdpvar(nTimeStep, 1);       % Power extracted from grid [kW]
pGridPos = sdpvar(nTimeStep, 1);    % Positive Grid Power 
pGridNeg = sdpvar(nTimeStep, 1);    % Negative Grid Power
pSurPeakPos = sdpvar(nTimeStep, 1); % Positive Sur Peak Power 
pSurPeakNeg = sdpvar(nTimeStep, 1); % Positive Sur Peak 

%% Problem Formulation - Constraints 

Ctotal = []; 

% C1 - Power Balance 
for t = 1:nTimeStep
    Ctotal = [
        Ctotal, 
        ( ...
            pGrid(t) + sum(pVehicle(t, :)) + ...
            data.pNetLoad(t) == 0 ...
            ):['1.' int2str(t)]
        ];
end

% C2.1 - Grid Power Separation 
Ctotal = [Ctotal, (pGridPos - pGridNeg == pGrid):'2.1'];

% C2.2 - Lower Bounds for pGridPos & pGridNeg & pVehicle 
Ctotal = [Ctotal, (pGridPos >= 0):'2.2.1'];
Ctotal = [Ctotal, (pGridNeg >= 0):'2.2.2'];
Ctotal = [Ctotal, (pVehicle <= 0):'2.2.3'];


% C3.1 Charging Variable Binding: bigM * ev >= (-pVehicle), (-pVehicle) <=
% pNom

C31 = []; 

for v = 1 : nSockets
    C31 = [
        C31, 
        ( pCharging(v) * ev(:, v) + pVehicle(:, v) == 0 ):['3.1.1' int2str(v)] 
        ];
end

% Variable Charging with a minimum threshold - bigM method
% for v = 1 : nSockets
%     C31 = [
%         C31, 
%         ( bigM * ev(:, v) + pVehicle(:, v) >= 0 ):['3.1.1' int2str(v)] 
%         ( 1 * ev(:, v) * pCharging(v) <= -pVehicle(:, v) <= pCharging(v) ):['3.1.2' int2str(v)]
%         ( bigM * ev(:, v) + pVehicle(:, v) >= 0 ):['3.1.3' int2str(v)]
%         ];
% end

Ctotal = [Ctotal, C31];

% C3.2 No Charging before arrival time: ev(t, v) = 0 if t < tArrival(v) 

C32 = [];

for v = 1 : nSockets
    C32 = [
        C32, (ev([1:nTimeStep] < tArrival(v), v) == 0):['3.2.' int2str(v)]
        ];
end

Ctotal = [Ctotal, C32];

% C4 - Maximum Sockets Occupation: sum_{v}(ev(t, v) <= nSockets)
% TODO: play with this 

C4 = []; 
for t = 1:nTimeStep
    C4 = [C4, ( sum(ev(t, :)) <= nSockets ):['1.' int2str(t)]];
end

Ctotal = [Ctotal, C4]; 

% C5.1 - SoC: 
% soc(t+1, v) == -eff(v) * (timeStep / 3600) * pVehicle(t, v) / c(v) + soc(t, v)

C51 = []; 
for v = 1 : nSockets
    C51 = [
        C51, 
        ( ...
        socVehicle(2:end, v) ...
        - socVehicle(1:end-1, v) ...
        + (timeStep / 3600) * efficiencyCharging(v) * pVehicle(1:end-1, v) / cEV(v) ...
        == 0 ...
        ):['5.1.' int2str(v)]
        ];
end

Ctotal = [Ctotal, C51]; 

% C5.2 - Initial SoC: soc(1, v) = socInit(v)
% This one has to stand alone so that it would be updated @ every iteration

C52 = ( socVehicle(1, :) == socInit ):'5.2';
Ctotal = [Ctotal, C52]; 


% C5.3 - Desired SoC: soc(tDeparture(v), v) >= socDesired(v)
% With this hard constrained, then the cost of tardiness is no longer
% necessary.
% TODO: replace this hard constraint later

% C53 = ( ...
%     socVehicle(sub2ind(size(socVehicle), tDeparture, 1:nSockets)) ...   % extract from subscript
%     >= socDesired ):'5.3';

C53 = [
    ( ...
    socVehicle(sub2ind(size(socVehicle), tDeparture, 1:nSockets)) ...   % extract from subscript
    - socDesired ...
    == socUnderChargedPos - socUnderChargedNeg):'5.3.1'
    ( socUnderChargedPos >= 0 ):'5.3.2'
    ( socUnderChargedNeg >= 0 ):'5.3.3'
];
% socUnderChargedPos = socVehicle - socDesired + socUnderChargedNeg >= 0

Ctotal = [Ctotal, C53];

% C5.4 SoC Bouds: 
% socVehicle(t, v) >= socMin, socVehicle(t, v) <= socMax
C54 = [ ( socVehicle >= socMin ):'5.4.min' ];
for v = 1 : nSockets
    C54 = [C54, 
        ( ...
        socVehicle(:, v) ...
        <= socMax ...
        ):['5.4.max.' int2str(v)] 
        ];
end
Ctotal = [Ctotal, C54];


% C6 - Demand Peak: pSurPeakPos == (peak - pGrid) + pSurPeakNeg >= 0

% C6 = (pGrid <= data.peakDemand):'6';
% Ctotal = [Ctotal, C6];

C6 = [
    ( pSurPeakPos - pSurPeakNeg == data.peakDemand - pGrid ):'6.1', 
    ( pSurPeakPos >= 0 ):'6.2', 
    ( pSurPeakNeg >= 0 ):'6.3' ... 
    ];
Ctotal = [Ctotal, C6];

% C7 - Socket Engagement 

%% Objective Function 

objFunc = ( ...
    sum(data.energyBuyPrice' * pGridPos) / nTimeStepHourly ...
    - sum(data.energySellPrice' * pGridNeg) / nTimeStepHourly ...
    - sum(ev, 'all') ... 
    + sum( data.demandBuyPrice' * pSurPeakNeg ) ...
    + sum( tardinessCost * socUnderChargedNeg' ) ...
);


% Solving The problem 
ops = sdpsettings( ...
    'solver','intlinprog', 'showprogress', true, 'savesolveroutput', true ...
    );
% This gap makes all the difference in solving time here
ops.intlinprog.RelativeGapTolerance = 1e-2;     
ops.intlinprog.MaxTime = 20;

% ops = sdpsettings();

dianostic = optimize(Ctotal, objFunc, ops);

if dianostic.problem == 0
    sdisplay(dianostic)
    disp('Objective Function: ')
    sdisplay(value(objFunc))
else    
    % For further error message, see 
    % https://yalmip.github.io/command/yalmiperror/
    warning('Error solving the problem')
end

utilities

%% Use initial guess 
% (INTLINPROG) does not support warm-starts through YALMIP

% assign(ev, value(ev));
% assign(pVehicle, value(pVehicle));
% assign(socVehicle, value(socVehicle));
% assign(pGrid, value(pGrid));
% assign(pGridPos, value(pGridPos));
% assign(pGridNeg, value(pGridNeg));
% assign(pSurPeakPos, value(pSurPeakPos));
% assign(pSurPeakNeg, value(pSurPeakNeg));

%% Post Processing
% utilities

%% Update Peak demand 
% data.peakDemand = 90 * ones(nTimeStep, 1); 
% Ctotal('6.1') = ( pSurPeakPos - pSurPeakNeg == data.peakDemand - pGrid ):'6.1';
% 
% % TODO: use initial solution/ warm start. 
% dianostic = optimize(Ctotal, objFunc, ops);
% 
% if dianostic.problem == 0
%     sdisplay(dianostic)
%     disp('Objective Function: ')
%     sdisplay(value(objFunc))
% else    
%     % For further error message, see 
%     % https://yalmip.github.io/command/yalmiperror/
%     warning('Error solving the problem')
% end


%% Constraints Verification Script 
% Ctemp = C6('6'); 
% 
% p = Polyhedron(Ctemp); spy(p.H);
% He = p.He;
% H = p.H;
% fullMatrix = full(getbase(Ctemp));
% spy(full(getbase(Ctemp)))