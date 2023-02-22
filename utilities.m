%% Visualisation 
set(0,'DefaultFigureWindowStyle','docked')

socMatrix = value(socVehicle);
timeMatrix = zeros(size(socMatrix));    % Arrival & departure indicators
timeMatrix(sub2ind(size(socMatrix), tArrival, 1:nSockets)) = 0.5;
timeMatrix(sub2ind(size(socMatrix), tDeparture, 1:nSockets)) = -0.5;
pVehicleMatrix = value(pVehicle);

% SoC
figure
h = heatmap( ...
    socMatrix, 'XLabel', 'Vehicles', 'YLabel', 'Time (t)', ...
    'Title', 'SoC' ...
    );
colormap('parula')

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


figure; bar(pVehicleMatrix,'stacked','DisplayName','pVehicleMatrix')

% Timelines 

%% Power Profiles 
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
    1:nTimeStep, -sum(value(pVehicle), 2), ...
    'Color', 'g', 'LineWidth', 1 , 'DisplayName', ' - Vehicles' ...
    ); hold on 

stairs( ...
    1:nTimeStep, data.peakDemand, ...
    'Color', 'b', 'LineWidth', 1 , 'DisplayName', 'Peak Level', ...
    'LineStyle', '--'); hold on 

legend
xlabel("Time")
ylabel("kW")
grid("on")

demandPriceIdx = find(diff(data.demandBuyPrice) ~= 0);

for idx = 1 : size(demandPriceIdx)
    xline(demandPriceIdx(idx), '--', 'Label', 'TOU Onpeak'); hold on
end

%% Information 
peakMaxScenario = sum(pCharging) - max(data.pNetLoad); % Peak in Max Scenario
nBinaryVars = yalmip('binvariables');       % Vector of binary variables
nVars = yalmip('nvars');                    % Vecor of variables
fprintf("Number of variables: %i \n", nVars)
fprintf("Number of binary variables: %i \n", size(nBinaryVars, 2));
fprintf("If all vehicles are charged at the same time, the peak " + ...
    "would be %i kW \n", sum(pCharging));
fprintf("Peak in Max Scenario would be %i kW.\n", round(peakMaxScenario));

%%
if ~isempty(find(round(sum(value(ev), 1)) == 0))
    warning("There are vehicles which are not charged in the " + ...
        "considered horizone:")
    fprintf("\t"); fprintf("%d ", find(round(sum(value(ev), 1)) == 0))
    fprintf("\n")
end

% F_struc = lmi2sedumistruct(Ctotal);         % Get matrix form of constraints

%% Verification

if ~all( ...
        socMatrix(sub2ind(size(socMatrix), tDeparture, 1:nSockets)) ...
        - socDesired >= -1e-2 ...
    )
    warning("The following vehicles are not charged to desired SoC at departue")

    fprintf( ...
        "\t %d", ...
        find( ...
            socMatrix(sub2ind(size(socMatrix), tDeparture, 1:nSockets)) ...
            - socDesired < -1e-5 ...
            ) ...
            )
    fprintf("\n")
end

% Check for soc init 
assert(all(socMatrix(1, :) == socInit), 'SoC Init not correct')

% Check if variables for constraint C5.3 are correct
% assert( ...
%     all( ...
%         getvariables( ...
%             socVehicle(sub2ind(size(socVehicle), tDeparture, 1:nSockets))' ...
%     ) ...
%         == getvariables(C53('5.3')) ...
%         ) ...
%     , 'Incorrect variable used.')
