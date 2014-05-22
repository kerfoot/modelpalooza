function rtofsProfiles = DbdGroup2LocalRtofsProfiles(dgroup, rtofsRoot, trajectoryTs, varargin)
%
% rtofsProfiles = DbdGroup2LocalRtofsProfiles(dgroup, rtofsRoot, trajectoryTs[, varargin])
%
% Searches rtofsRoot for RTOFS forecasts and finds the closest RTOFS
% modeled profile to each profile contained in dgroup, which must be an
% instance of the DbdGroup class.
%
% The return value, rtofsProfiles, is a structured array containing the
% profile data from the closest profile in the forecast, both in time and
% space.  All four RTOFS forecast files (temp, salt, uvel, vvel) must be
% found for the profile to be considered valid.  rtofsProfiles is typically
% fed to writeRtofsVirtualGliderFlatNc to write NetCDF files to be served
% via ERDDAP.
%
% See also findRtofsBoundingProfiles writeRtofsVirtualGliderFlatNc DbdGroup
%
% ============================================================================
% $RCSfile$
% $Source$
% $Revision$
% $Date$
% $Author$
% ============================================================================
%

app = mfilename;
rtofsProfiles = [];

% Validate inputs
if nargin < 2
    fprintf(2,...
        '%s:nargin: 2 arguments are required\n',...
        app);
    return;
elseif ~isa(dgroup, 'DbdGroup')
    fprintf(2,...
        '%s:invalidArgument: dgroup must be an instance of the DbdGroup class\n',...
        app);
    return;
elseif isempty(rtofsRoot) || ~ischar(rtofsRoot) || ~isdir(rtofsRoot)
    fprintf(2,...
        '%s:invalidArgument: RTOFS_ROOT must be a valid directory\n',...
        app);
    return;
elseif ~isequal(numel(trajectoryTs),1) || ~isnumeric(trajectoryTs)
    fprintf(2,...
        '%s:invalidArgument: trajectoryTs must be a Matlab datenum representing the deployment start date\n',...
        app);
    return;
elseif ~isequal(mod(length(varargin),2),0)
    fprintf(2,...
        '%s:varargin: Invalid number of options specified\n',...
        app);
    return;
end

% Settings
% RTOFS nc file template
RTOFS_NC_TEMPLATE = '_rtofs_glo_3dz_nowcast_daily_';
% RTOFS nc file types and target variables
RTOFS_FTYPES = struct('temp', 'temperature',...
    'salt', 'salinity',...
    'uvel', 'u',...
    'vvel', 'v');
rtofsVars = fieldnames(RTOFS_FTYPES);

% Defaults
VALID_METHODS = {'nearest',...
    'interp3d',...
    }';
METHOD = VALID_METHODS{1};
% Process options
for x = 1:2:length(varargin)
    
    name = varargin{x};
    value = varargin{x+1};
    
    switch lower(name)
        case 'method'
            if ~ischar(value) || isempty(value)
                fprintf(2,...
                    '%s:invalidOptionValue: value for option %s must be a string specifying a valid method\n',...
                    app,...
                    name);
                return;
            elseif ~ismember(value, VALID_METHODS)
                fprintf(2,...
                    '%s:invalidMethod: invalid method specified: %s\n',...
                    app,...
                    value);
                return;
            end
            METHOD = lower(value);
        otherwise
            fprintf(2,...
                '%s:invalidOption: Invalid option specified: %s\n',...
                app,...
                name);
            return;
    end
end

% Export the DbdGroup as profiles
p = dgroup.toProfiles();

% Create the profile data strcuture that will be used to write data to the
% NetCDF file
VAR_STRUCT = struct('ncVarName', '',...
    'data', []);
META_STRUCT = struct('glider', '',...
    'startDatenum', NaN,...
    'endDatenum', NaN,...
    'lonLat', []);
rtofsProfiles(length(p)).profile_id = NaN;
rtofsProfiles(length(p)).meta = META_STRUCT;
rtofsProfiles(length(p)).vars = VAR_STRUCT;

for x = 1:length(p)
    
    rtofsProfiles(x).profile_id = NaN;
    
    % Next profile if no GPS
    if any(isnan(p(x).meta.lonLat))
        continue;
    end
    
    ts = datestr(p(x).meta.startDatenum, 'yyyymmdd');
    
    % Create the RTOFS subset directory corresponding to the target 
    % timestamp
    RTOFS_FORECAST_DIR = fullfile(rtofsRoot, ts, ts);
    fprintf(1,...
        'Searching latest forecasts for %s: %s\n',...
        ts,...
        RTOFS_FORECAST_DIR);
    rtofsFiles = dir2cell(dir(fullfile(RTOFS_FORECAST_DIR, ['*' RTOFS_NC_TEMPLATE '*.nc'])),...
        RTOFS_FORECAST_DIR);
    if ~isequal(length(rtofsFiles),4)
        fprintf(2,...
            'Latest forecast not available.\n');
        ts = datestr(p(x).meta.startDatenum - 1, 'yyyymmdd');
        % Create the RTOFS subset directory corresponding to the target 
        % timestamp
        RTOFS_FORECAST_DIR = fullfile(rtofsRoot, ts, ts);
        fprintf(1,...
            'Searching previous day forecasts for %s: %s\n',...
            ts,...
            RTOFS_FORECAST_DIR);
        
        rtofsFiles = dir2cell(dir(fullfile(RTOFS_FORECAST_DIR, ['*' RTOFS_NC_TEMPLATE '*.nc'])),...
            RTOFS_FORECAST_DIR);
        
        if ~isequal(length(rtofsFiles),4)
            fprintf(2,...
                'Previous day forecast not available.\n');
            continue;
        end
        
    end
    
    % Make sure we have all 4 RTOFS subset files
    hasFiles = true;
    for f = 1:length(rtofsVars)

        fMatch = find(~cellfun(@isempty, regexp(rtofsFiles, rtofsVars{f}, 'once')) == 1);
        if isempty(fMatch)
            fprintf(2,...
                'Invalid RTOFS subset file: %s\n',...
                rtofsNc);
            hasFiles = false;
            break;
        end
    end
    
    if ~hasFiles
        fprintf(2,...
            'Skipping profile %d: Missing one or more required RTOFS subset files.\n',...
            x);
        continue;
    end
    
    % Add the structure fields    
    rtofsProfiles(x).meta = META_STRUCT;
    rtofsProfiles(x).vars = VAR_STRUCT;
    
    for f = 1:length(rtofsVars)
        
        % See if any NetCDF files exist for the current variable
        ncFiles = dir2cell(dir(fullfile(RTOFS_FORECAST_DIR, ['*' ts RTOFS_NC_TEMPLATE rtofsVars{f} '.nc4.nc'])),...
            RTOFS_FORECAST_DIR);
        if ~isequal(length(ncFiles),1)
            fprintf(2,...
                '%s:%s: NetCDF file not found\n',...
                app,...
                rtofsVars{f});
            continue;
        end

        rtofsNc = ncFiles{1};
        
        % Grab the RTOFS bounding profiles for the specified gps
        rtofsP = findRtofsBoundingProfiles(rtofsNc,...
            RTOFS_FTYPES.(rtofsVars{f}),...
            p(x).meta.lonLat(2),...
            p(x).meta.lonLat(1),...
            'dtimes', p(x).meta.startDatenum);

        if isempty(rtofsP)
            continue;
        end
        
        numRows = size(rtofsP.Profiles(5).Data,1);
        
        % Fill in the retreived profile metadata once
        if isempty(rtofsProfiles(x).meta.lonLat)
            rtofsProfiles(x).meta.glider = p(x).meta.glider;
            rtofsProfiles(x).meta.startDatenum = p(x).meta.startDatenum;
            rtofsProfiles(x).meta.endDatenum = p(x).meta.endDatenum;
            rtofsProfiles(x).meta.lonLat = rtofsP.Profiles(5).LonLat;
        end

        % Fill in the rtofsProfiles data
        rtofsProfiles(x).vars(f).ncVarName = RTOFS_FTYPES.(rtofsVars{f});
        rtofsProfiles(x).vars(f).data = rtofsP.Profiles(5).Data(:,2);

    end

    % Fill in the profile_id field
    rtofsProfiles(x).profile_id = x;
    
    % Add the time variable by creating a linear array interpolated between
    % the p(x).meta.startDatenum and p(x).meta.endDatenum and convert them
    % to epoch times
    rtofsProfiles(x).vars(end+1).ncVarName = 'time';
    timeArray = datenum2epoch(linspace(p(x).meta.startDatenum,...
        p(x).meta.endDatenum,...
        numRows));
    rtofsProfiles(x).vars(end).data = timeArray;
    
    % Add the profile_id variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'profile_id';
    rtofsProfiles(x).vars(end).data = x;
    
    % Add the profile_lat variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'profile_lat';
    rtofsProfiles(x).vars(end).data = rtofsP.Profiles(5).LonLat(2);
    
    % Add the profile_lon variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'profile_lon';
    rtofsProfiles(x).vars(end).data = rtofsP.Profiles(5).LonLat(1);
    
    % Add the profile_time variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'profile_time';
    rtofsProfiles(x).vars(end).data = mean(timeArray);
    
    % Create the trajectory string name
    trajectoryStr = sprintf('%s-RTOFS-%s',...
        p(x).meta.glider,...
        datestr(trajectoryTs, 'yyyymmddTHHMM'));
    % Add the trajectory string variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'trajectory';
    rtofsProfiles(x).vars(end).data = trajectoryStr;
    
    % Add the depth data variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'depth';
    rtofsProfiles(x).vars(end).data = rtofsP.Profiles(5).Data(:,1);

    % Add the profile_lat variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'lat';
    rtofsProfiles(x).vars(end).data = repmat(rtofsP.Profiles(5).LonLat(2),...
        numRows,...
        1);
    
    % Add the profile_lon variable
    rtofsProfiles(x).vars(end+1).ncVarName = 'lon';
    rtofsProfiles(x).vars(end).data = repmat(rtofsP.Profiles(5).LonLat(1),...
        numRows,...
        1);
    
    % Calculate and add density
    RTOFS_VARS = {rtofsProfiles(x).vars.ncVarName};
    [~,ZI] = ismember('depth', RTOFS_VARS);
    [~,TI] = ismember('temperature', RTOFS_VARS);
    [~,SI] = ismember('salinity', RTOFS_VARS);
    rtofsProfiles(x).vars(end+1).ncVarName = 'density';
    rtofsProfiles(x).vars(end).data = sw_dens(rtofsProfiles(x).vars(SI).data,...
        rtofsProfiles(x).vars(TI).data,...
        rtofsProfiles(x).vars(ZI).data);
    
end