
timeStep = 900;     % sec
horizonHours = 18;  % hour
nSockets = 30;  % Nbr of Sockets of Chargers = Nbr of Vehicles considered.
nTimeStep = horizonHours * 3600 / timeStep; 
nTimeStepHourly = 3600 / timeStep;      % Number of time step per hour 
bigM = 1e6; 
startTime = 6;      % The horizon starts at 6 am 


% demand Price
