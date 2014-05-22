DEPLOYMENTS_ROOT = '/home/kerfoot/sandbox/glider/deployments-test';
DID = 401;
% Select the glider name for the specified deployment id
[s,m] = unix(sprintf('/home/kerfoot/slocum/rucool/sql/did2glider.sh %d',...
    DID));
if ~isequal(s,0)
    fprintf(2,...
        'Invalid deployment id: %d\n',...
        DID);
    return;
end
GLIDER = deblank(m);
% Select the deployment year for the specified deployment id
[s,m] = unix(sprintf('/home/kerfoot/slocum/rucool/sql/did2deployedYear.sh %d',...
    DID));
if ~isequal(s,0)
    fprintf(2,...
        'Invalid deployment id: %d\n',...
        DID);
    return;
end
YYYY = deblank(m);
deployment = sprintf('%s-%d',...
    GLIDER,...
    DID);
% Select the deployment epoch time start timestamp for the specified deployment id
[s,m] = unix(sprintf('/home/kerfoot/slocum/rucool/sql/did2deployedEpoch.sh %d',...
    DID));
if ~isequal(s,0)
    fprintf(2,...
        'Invalid deployment id: %d\n',...
        DID);
    return;
end
trajectoryStr = sprintf('%s-RTOFS-%s',...
    GLIDER,...
    datestr(epoch2datenum(str2double(m)), 'yyyymmddTHHMM'));

dgroupDir = fullfile(DEPLOYMENTS_ROOT, YYYY, deployment);
% DbdGroup file to process
dgroupFile = fullfile(dgroupDir, [deployment '_DbdGroup_sci-qc0.mat']);
if ~exist(dgroupFile, 'file')
    fprintf(2,...
        'Invalid DbdGroup file: %s\n',...
        dgroupFile);
    return;
end
% Load the file
load(dgroupFile);
% Export as profiles
p = dgroup.toProfiles();

% RTOFS subsets
RTOFS_ROOT = '/home/coolgroup/RTOFS/forecasts/gliders/ru29-401';
% RTOFS nc file template
RTOFS_NC_TEMPLATE = '_rtofs_glo_3dz_nowcast_daily_';
% RTOFS nc file types and target variables
RTOFS_FTYPES = struct('temp', 'temperature',...
    'salt', 'salinity',...
    'uvel', 'u',...
    'vvel', 'v');
rtofsVars = fieldnames(RTOFS_FTYPES);

% Create the profile data strcuture that will be used to write data to the
% NetCDF file
VAR_STRUCT = struct('ncVarName', '',...
    'data', []);
META_STRUCT = struct('glider', '',...
    'startDatenum', NaN,...
    'endDatenum', NaN,...
    'lonLat', []);
pStruct(length(p)).meta = META_STRUCT;
pStruct(length(p)).vars = VAR_STRUCT;

% for x = 1:length(p)
for x = 1:length(p)
    
    pStruct(x).profile_id = NaN;
    
    % Next profile if no GPS
    if any(isnan(p(x).meta.lonLat))
        continue;
    end
    
    ts = datestr(p(x).meta.startDatenum, 'yyyymmdd');
    
    % Create the RTOFS subset directory corresponding to the target 
    % timestamp
    RTOFS_FORECAST_DIR = fullfile(RTOFS_ROOT, ts, ts);
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
        RTOFS_FORECAST_DIR = fullfile(RTOFS_ROOT, ts, ts);
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
    pStruct(x).meta = META_STRUCT;
    pStruct(x).vars = VAR_STRUCT;
    
    for f = 1:length(rtofsVars)
        
        rtofsNc = fullfile(RTOFS_FORECAST_DIR, [deployment '_' ts RTOFS_NC_TEMPLATE rtofsVars{f} '.nc4.nc']);

        if ~exist(rtofsNc, 'file')
            
        end

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
        if isempty(pStruct(x).meta.lonLat)
            pStruct(x).meta.glider = GLIDER;
            pStruct(x).meta.startDatenum = p(x).meta.startDatenum;
            pStruct(x).meta.endDatenum = p(x).meta.endDatenum;
            pStruct(x).meta.lonLat = rtofsP.Profiles(5).LonLat;
        end

        % Fill in the pStruct data
        pStruct(x).vars(f).ncVarName = RTOFS_FTYPES.(rtofsVars{f});
        pStruct(x).vars(f).data = rtofsP.Profiles(5).Data(:,2);

    end

    % Fill in the profile_id field
    pStruct(x).profile_id = x;
    
    % Add the time variable by creating a linear array interpolated between
    % the p(x).meta.startDatenum and p(x).meta.endDatenum and convert them
    % to epoch times
    pStruct(x).vars(end+1).ncVarName = 'time';
    timeArray = datenum2epoch(linspace(p(x).meta.startDatenum,...
        p(x).meta.endDatenum,...
        numRows));
    pStruct(x).vars(end).data = timeArray;
    
    % Add the profile_id variable
    pStruct(x).vars(end+1).ncVarName = 'profile_id';
    pStruct(x).vars(end).data = x;
    
    % Add the profile_lat variable
    pStruct(x).vars(end+1).ncVarName = 'profile_lat';
    pStruct(x).vars(end).data = rtofsP.Profiles(5).LonLat(2);
    
    % Add the profile_lon variable
    pStruct(x).vars(end+1).ncVarName = 'profile_lon';
    pStruct(x).vars(end).data = rtofsP.Profiles(5).LonLat(1);
    
    % Add the profile_time variable
    pStruct(x).vars(end+1).ncVarName = 'profile_time';
    pStruct(x).vars(end).data = mean(timeArray);
    
    % Add the trajectory string variable
    pStruct(x).vars(end+1).ncVarName = 'trajectory';
    pStruct(x).vars(end).data = trajectoryStr;
    
    % Add the depth data variable
    pStruct(x).vars(end+1).ncVarName = 'depth';
    pStruct(x).vars(end).data = rtofsP.Profiles(5).Data(:,1);

    % Add the profile_lat variable
    pStruct(x).vars(end+1).ncVarName = 'lat';
    pStruct(x).vars(end).data = repmat(rtofsP.Profiles(5).LonLat(2),...
        numRows,...
        1);
    
    % Add the profile_lon variable
    pStruct(x).vars(end+1).ncVarName = 'lon';
    pStruct(x).vars(end).data = repmat(rtofsP.Profiles(5).LonLat(1),...
        numRows,...
        1);
    
    % Calculate and add density
    RTOFS_VARS = {pStruct(x).vars.ncVarName};
    [~,ZI] = ismember('depth', RTOFS_VARS);
    [~,TI] = ismember('temperature', RTOFS_VARS);
    [~,SI] = ismember('salinity', RTOFS_VARS);
    pStruct(x).vars(end+1).ncVarName = 'density';
    pStruct(x).vars(end).data = sw_dens(pStruct(x).vars(SI).data,...
        pStruct(x).vars(TI).data,...
        pStruct(x).vars(ZI).data);
    
end