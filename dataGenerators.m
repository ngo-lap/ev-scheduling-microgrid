%% Demand Price 
function dataProfile = dataGenerators( dataType, ...
    startHour, onPeak, timeStep, horizonHours ...
    )
    
    nTimeStep = horizonHours * 3600 / timeStep;     % Number of timesteps in the horizon
    nTimeStepHourly = 3600 / timeStep;              % Number of time step per hour 

    switch dataType 
        case 'demand'
            dataProfile = generateDemandPrice( ...
                startHour, onPeak, nTimeStep, nTimeStepHourly ...
                );
        case 'energy'
            dataProfile = (1 / nTimeStepHourly) * ones(nTimeStep, 1);
    end
end

function demandPrice = generateDemandPrice( ...
    startHour, onPeak, nTimeStep, nTimeStepHourly ...
    )

    % startHour: the time to start the horizon (ex: 6 == 6 AM)
    % onPeak = [12, 16];      % On-Peak from 12-15, 16 exclusive
    % timeStep: time step in seconds
    % horizonHours: the horizon in hours 
    % Example: 
    %   demandPrice = generateDemandPrice(6, [12, 16], 3600, 18);
    %   stairs(demandPrice)

    % Preprocessing

    % Translated to timesteps
    onPeakTranslated = nTimeStepHourly*(onPeak - startHour);    
    
    % Generate The On Peak Price Profile: on peak -> 20, off peak -> 10
    demandPrice = 10 * ones(nTimeStep, 1); 
    demandPrice( onPeakTranslated(1):(onPeakTranslated(2)-1) ) = 20;
end
