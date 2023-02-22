
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

%% 

requiredVehicleEnergy = cEV * ( ...
    (socDesired  - socInit) ./ efficiencyCharging ...
    )';     % kWh

expectedNetLoadEnergy = sum(data.pNetLoad) / nTimeStepHourly;

%% 

peakMaxScenario = sum(pCharging) - max(data.pNetLoad); 
