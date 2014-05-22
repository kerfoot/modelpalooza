function rtofs_profiles = findRtofsBoundingProfiles(rtofs_nc, variable, lat, lon, varargin)
%
% rtofs_profiles = findRtofsBoundingProfiles(rtofs_nc, variable, lat, lon[, varargin])
%
% Retrieve the variable profiles from rtofs_nc which include the closest 
% profile to the specified lat & lon as well as the 8 surrounding profiles.  
% The bounding profiles are retrieved for all forecast times contained in the 
% forecast file.
%
% variable must be a valid 4-D [lon lat depth time] variable contained in the
% forecast file.
%
% The following name,value options may be used to modify which profiles are
% selected:
%
%   'dtimes': array of matlab datenums.  For each value specified, the profiles
%   for the closest foreast time are retrieved.
%
% ============================================================================
% $RCSfile$
% $Source$
% $Revision$
% $Date$
% $Author$
% ============================================================================
%

rtofs_profiles = [];

% Validate input args
if nargin < 4 % At least 3 argument required
    error('findRtofsBoundingProfiles:nargin',...
        'You must specify a forecast file, variable, longitude and latitude');
elseif ~ischar(variable)
    error('findRtofsBoundingProfiles:invalidDataType',...
        'The variable name must be a string.');
elseif isempty(lat) ||...
        ~isequal(numel(lat),1) ||...
        ~isnumeric(lat) ||...
        lat < -90 ||...
        lat > 90
    error('findRtofsBoundingProfiles:invalidLat',...
        'The latitude argument must be a number inclusive of -90 and 90');
elseif isempty(lon) ||...
        ~isequal(numel(lon),1) ||...
        ~isnumeric(lon) ||...
        lon < -180 ||...
        lon > 180
    error('findRtofsBoundingProfiles:invalidLon',...
        'The longitude argument must be a number inclusive of -180 and 180');
elseif ~isequal(mod(length(varargin),2), 0)
    error('findRtofsBoundingProfiles:invalidArgument',...
        'Invalid number of name,value options specified.');
end

% Process options
DTIMES = [];
for x = 1:2:length(varargin)
    name = varargin{x};
    value = varargin{x+1};
    if isempty(value)
        error('findRtofsBoundingProfiles:invalidOption',...
            'Value for option %s is empty.',...
            name);
    end
    
    switch lower(name)
        case 'dtimes'
            if any(~isnumeric(value))
                error('findRtofsBoundingProfiles:invalidOptionValue',...
                    'Value for option %s must be an array of datenums.',...
                    name);
            end
            DTIMES = value(:);
        otherwise
            error('findRtofsBoundingProfiles:invalidOption',...
                'Invalid option specified: %s',...
                name);
    end
end

REQUIRED_VARS = {'lat',...
    'lon',...
    'lev',...
    'time',...
    }';
T_COUNT = 1;
LAT_COUNT = 3;
LON_COUNT = 3;

% Retrieve the file structure
try
    nci = ncinfo(rtofs_nc);
catch ME
    warning(ME.identifier, ME.message);
    return;
end

% Get the list of variables
vars = {nci.Variables.Name}';

% Make sure this file has the required variables
C = ismember(REQUIRED_VARS, vars);
if ~all(C)
    warning('findRtofsBoundingProfiles:missingVariables',...
        'At least one required variable is missing from the forecast: %s\n',...
        rtofs_nc);
    return;
end

% Select available times
fprintf(1,...
    'Retrieving forecast times...');
try
    rtofs_dtimes = ncread(rtofs_nc, 'time');
catch ME
    fprintf(2,...
        'Failed.\n%s: %s\n',...
        ME.identifier,...
        ME.message);
    return;
end
fprintf(1, '\n');
if isempty(rtofs_dtimes)
    error('findRtofsBoundingProfiles:NetCDF',...
        'Forecast file contains no timesteps.');
end
% Store the count
NUM_TIMES = length(rtofs_dtimes);

% Select available latitudes
fprintf(1,...
    'Retrieving model latitudes...');
try
    rtofs_lats = ncread(rtofs_nc, 'lat');
catch ME
    fprintf(2,...
        'Failed.\n%s: %s\n',...
        ME.identifier,...
        ME.message);
    return;
end
fprintf(1, '\n');

if isempty(rtofs_lats)
    error('findRtofsBoundingProfiles:NetCDF',...
        'Forecast file contains no latitudes.');
end
NUM_LATS = length(rtofs_lats);

% Select available longitudes
fprintf(1,...
    'Retrieving model longitudes...');
try
    rtofs_lons = ncread(rtofs_nc, 'lon');
catch ME
    fprintf(2,...
        'Failed.\n%s: %s\n',...
        ME.identifier,...
        ME.message);
    return;
end
fprintf(1, '\n');

if isempty(rtofs_lons)
    error('findRtofsBoundingProfiles:NetCDF',...
        'Forecast file contains no longitudes.');
end
NUM_LONS = length(rtofs_lons);

% Select available depths
fprintf(1,...
    'Retrieving model depth levels...');
try
    rtofs_depths = ncread(rtofs_nc, 'lev');
catch ME
    fprintf(2,...
        'Failed.\n%s: %s\n',...
        ME.identifier,...
        ME.message);
    return;
end
fprintf(1, '\n');

if isempty(rtofs_depths)
    error('findRtofsBoundingProfiles:NetCDF',...
        'Forecast file contains no depth levels.');
end

% If no times were specified, retrieve the bounding profiles for each
% forecast timestamp
if isempty(DTIMES)
    DTIMES = rtofs_dtimes;
end

for t = 1:length(DTIMES)
    
    % Current search time
    dtime = DTIMES(t);
    
    % SELECT FORECAST TIME INDEX ---------------------------------------------
    % Calculate the difference between the current search time and the
    % forecast times
    delta_t = rtofs_dtimes - dtime;
    % Store the index of the forecast time if it is an exact match to the
    % current search time
    if any(~delta_t)
        T_START = find(~delta_t);
        T_START = T_START(1);
    else
        % If there is no exact match, select the forecast time that is closest
        % to the current search time.  If the current search time is exactly
        % in between 2 forecast times, the earlier forecast time is selected.
        [C,T_START] = min(abs(delta_t));
    end
    % ------------------------------------------------------------------------
    
    % SELECT LATITUDES INDEX -------------------------------------------------
    delta_lat = rtofs_lats - lat;
    LAT_START = find(delta_lat == 0);
    if ~isempty(LAT_START)
        LAT_START = LAT_START(1);
    else
        [C,LAT_START] = min(abs(delta_lat));
    end
    LAT_TEMPLATE = [true true true];
    if isequal(LAT_START,0)
        LAT_COUNT = 2;
        LAT_TEMPLATE = [false true true];
    elseif isequal(LAT_START, NUM_LATS)
        LAT_START = LAT_START - 1;
        LAT_COUNT = 2;
        LAT_TEMPLATE = [true true false];
    else
        LAT_START = LAT_START - 1;
    end
    % ------------------------------------------------------------------------
   
    % SELECT LONGITUDES INDEX ------------------------------------------------
    % Convert WGS longitude to RTOFS longitude coordinate space
    rlon = lons2RtofsLons(lon);
    delta_lon = rtofs_lons - rlon;
    LON_START = find(delta_lon == 0);
    if ~isempty(LON_START)
        LON_START = LON_START(1);
    else
        [C,LON_START] = min(abs(delta_lon));
    end
    LON_TEMPLATE = [true true true];
    if isequal(LON_START,0)
        LON_COUNT = 2;
        LON_TEMPLATE = [false true true];
    elseif isequal(LON_START, NUM_LONS)
        LON_START = LON_START - 1;
        LON_COUNT = 2;
        LON_TEMPLATE = [true true flase];
    else
        LON_START = LON_START - 1;
    end
    % ------------------------------------------------------------------------   
    
    % Retrieve the latitdues
    lat_data = nan(3,1);
    lat_data(LAT_TEMPLATE) = ncread(rtofs_nc,...
        'lat',...
        LAT_START,...
        LAT_COUNT);
    
    % Retrieve the longitudes using LON_TEMPLATE 
    lon_data = nan(1,3);
    lon_data(LON_TEMPLATE) = rtofsLons2Lons(ncread(rtofs_nc,...
        'lon',...
        LON_START,...
        LON_COUNT));
    
    % Retrieve the variable
    var_data = nan(length(lat_data), length(lon_data), length(rtofs_depths));
    var_data = ncread(rtofs_nc,...
        variable,...
        [LON_START LAT_START 1 T_START],...
        [LON_COUNT LAT_COUNT inf T_COUNT]);
    
    % Create the fetched lat/lon grids
    LATI = repmat(lat_data, 1, length(lon_data));
    LONI = repmat(lon_data, length(lat_data), 1);
    
    % Fill in the rtofs_profiles structure by traversing the LATI/LONI grids.
    % The grids hold the profiles in the following location orders
    %    1  2  3
    % 1  sw ss se
    % 2  ww cc ee
    % 3  nw nn ne
    
    % SouthWest profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(1).Location = 'SouthWest';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(1,1) LATI(1,1)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(1,1,:))];
    
    % SouthSouth profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'SouthSouth';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(1,2) LATI(1,2)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(1,2,:))];
    
    % SouthEast profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'SouthEast';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(1,3) LATI(1,3)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(1,3,:))];
    
    % WestWest profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'WestWest';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(2,1) LATI(2,1)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(2,1,:))];
    
    % SouthSouth profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'CenterCenter';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(2,2) LATI(2,2)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(2,2,:))];
    
    % SouthEast profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'EastEast';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(2,3) LATI(2,3)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(2,3,:))];
    
    % NorthWest profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'NorthWest';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(3,1) LATI(3,1)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(3,1,:))];
    
    % NorthNorth profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'NorthNorth';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(3,2) LATI(3,2)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(3,2,:))];
    
    % NorthEast profile
    rtofs_profiles(t).ForecastTime = dtime;
    rtofs_profiles(t).Profiles(end+1).Location = 'NorthEast';
    rtofs_profiles(t).Profiles(end).LonLat = [LONI(3,3) LATI(3,3)];
    rtofs_profiles(t).Profiles(end).Variable = variable;
    rtofs_profiles(t).Profiles(end).Data = [rtofs_depths squeeze(var_data(3,3,:))];
end