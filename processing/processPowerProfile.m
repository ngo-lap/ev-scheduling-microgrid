function [ profileArray, profileTimetable ] = processPowerProfile( ...
    dataAnnual, startTime, horizonHours, timeStep ...
    )
% pvProfile - create a sample daily pv profile from annual data 
%   dataAnnual [timetable]: Power Profile (kW) such that average would be 
%       the method of resampling 
%   startTime [str]: timestamp of the desired start time
%   horizonHours [int]: the length of the horizon (in hours)
%   timeStep [int]: the time step in seconds 

    range2extract = timerange( ...
        datetime(startTime), ...
        datetime(startTime) + hours(horizonHours), ...
        'closedright' ...
        );
    
    if isnan(dataAnnual.Properties.TimeStep)
        originalTimeStep = seconds(900);
    else
        originalTimeStep = dataAnnual.Properties.TimeStep;
    end
    newTimeStep = seconds(timeStep);

    if originalTimeStep < newTimeStep 
        profileTimetable = retime( ...
            dataAnnual(range2extract, :), 'regular', 'mean', ...
            'TimeStep', newTimeStep ...
            );
        profileArray = profileTimetable.Variables;

    elseif originalTimeStep > newTimeStep
        profileTimetable = retime( ...
            dataAnnual(range2extract, :), 'regular', 'previous', ...
            'TimeStep', newTimeStep ...
            );

        % The first time stamp is omitted in retime
        profileArray = profileTimetable.Variables;
        profileArray = [profileArray(1); profileArray]; 

    else
        profileTimetable = dataAnnual(range2extract, :);
        profileArray = profileTimetable.Variables;
    end
    

end