%% Visualisation 
set(0,'DefaultFigureWindowStyle','docked')

socMatrix = value(socVehicle);
timeMatrix = zeros(size(socMatrix));    % Arrival & departure indicators
timeMatrix(sub2ind(size(socMatrix), tArrival, 1:nSockets)) = 0.5;
timeMatrix(sub2ind(size(socMatrix), tDeparture, 1:nSockets)) = -0.5;

% SoC
figure
h = heatmap( ...
    socMatrix, 'XLabel', 'Vehicles', 'YLabel', 'Time (t)', ...
    'Title', 'SoC' ...
    );

% figure 
% heatmap( ...
%     timeMatrix, 'XLabel', 'Vehicles', 'YLabel', 'Time (t)', ...
%     'Title', 'Departure & Arrival', 'ColorbarVisible', 'off' ...
%     )
% colormap("parula")

figure
heatmap( ...
    round(value(ev)) + timeMatrix, 'XLabel', 'Vehicles', ...
    'YLabel', 'Time (t)', 'Title', 'EV Charging (1 or 0), Arrival(0.5) & Departure (-0.5), ', ...
    'ColorbarVisible', 'off'...
    )
colormap('jet')

figure
heatmap(value(pVehicle), 'XLabel', 'Vehicles', 'YLabel', 'Time (t)', 'Title', 'pVehicle')

% h = bar3(socMatrix); 

% Timelines 

% Power Profiles 
figure
stairs( ...
    1:nTimeStep, value(pGrid), ...
    'Color', 'b', 'LineWidth', 1, 'DisplayName', 'Grid' ...
    ); hold on 

stairs( ...
    1:nTimeStep, value(data.pNetLoad), ...
    'Color', 'r', 'LineWidth', 1, 'DisplayName', 'Net Load' ...
    ); hold on 

stairs( ...
    1:nTimeStep, sum(value(pVehicle), 2), ...
    'Color', 'g', 'LineWidth', 1 , 'DisplayName', 'Vehicles' ...
    ); hold on 

legend
xlabel("kW")
ylabel("Time")
grid("on")

%% Verification

% Check for Soc Desire at departure
assert( ...
    all(socMatrix(sub2ind(size(socMatrix), tDeparture, 1:nSockets)) ...
    == socDesired), 'SoC not at the desired level at departure' ...
    )

% Check for soc init 
assert(all(socMatrix(1, :) == socInit), 'SoC Init not correct')

%% Information 

nBinaryVars = yalmip('binvariables');       % Vector of binary variables
nVars = yalmip('nvars');                    % Vecor of variables
fprintf("Number of variables: %i \n", nVars)
fprintf("Number of binary variables: %i \n", size(nBinaryVars, 2));
fprintf("If all vehicles are charged at the same time, the peak " + ...
    "would be %i kW \n", sum(pCharging));
%%
if ~isempty(find(round(sum(value(ev), 1)) == 0))
    warning("There are vehicles which are not charged in the " + ...
        "considered horizone:")
    fprintf("\t"); fprintf("%d ", find(round(sum(value(ev), 1)) == 0))
    fprintf("\n")
end

% F_struc = lmi2sedumistruct(Ctotal);         % Get matrix form of constraints