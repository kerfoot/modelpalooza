function outFile = writeRtofsVirtualGliderFlatNc(pStruct, varargin)
%
% outFile = writeRtofsVirtualGliderFlatNc(pStruct[,varargin])
%
% Accepts a single profile contained in pStruct, returned from 
% DbdGroup2LocalRtofsProfiles.m, and writes a NetCDF file to be served via
% ERDDAP.
%
% Options:
% 'clobber', [true or false]: by default, existing NetCDF files are not 
%   overwritten.  Set to true to overwrite existing files.
% 'attributes', STRUCT: structured array mapping global NetCDF file
%   attributes to values.  If not specified, default values are taken from 
%   the NetCDF template file and written.
% 'outfile', STRING: the NetCDF filename is constructed from the .meta
%   field.  Use this option to specify a custom filename.
% 'outdirectory', STRING: NetCDF files are written to the current working
%   directory.  Use this option to specify an alternate path.
%
% See also DbdGroup2LocalRtofsProfiles
%
% ============================================================================
% $RCSfile$
% $Source$
% $Revision$
% $Date$
% $Author$
% ============================================================================
%

outFile = '';
app = mfilename;

REQUIRED_FIELDS = {'meta',...
    'vars',...
    }';
REQUIRED_NC_VARS = {'time',...
    'trajectory',...
    'lat',...
    'lon',...
    'depth',...
    'temperature',...
    'salinity',...
    'density',...
    'u',...
    'v',...
    'profile_id',...
    'profile_time',...
    'profile_lat',...
    'profile_lon',...
    }';
DATENUM_CUTOFF = datenum(2100,1,1);
MODEL = 'RTOFS';
% Validate input args
if nargin < 2
    warning(sprintf('%s:nargin', app),...
        '2 arguments are required');
    return;
elseif ~isstruct(pStruct) ||...
        ~isequal(length(pStruct),1) ||...
        ~isequal(length(REQUIRED_FIELDS), length(intersect(REQUIRED_FIELDS,fieldnames(pStruct))))
    warning(sprintf('%s:invalidArgument', app),...
        'pStruct must be a structured array containing appropriate fields.');
    return;
elseif isempty(pStruct.meta) || isempty(pStruct.vars)
    warning(sprintf('%s:invalidArgument', app),...
        'pStruct fields are empty.');
    return;
end

% Default options
CLOBBER = false;
GLOBAL_ATTRIBUTES = [];
OUT_DIR = pwd;
outFile = '';
% Process options
for x = 1:2:length(varargin)
    name = varargin{x};
    value = varargin{x+1};
    switch lower(name)
        case 'clobber'
            if ~isequal(numel(value),1) || ~islogical(value)
                error(sprintf('%s:invalidOptionValue', app),...
                    'Value for option %s must be a logical value',...
                    name);
            end
            CLOBBER = value;
        case 'attributes'
            if ~isstruct(value) || ~isequal(length(struct),1)
                error(sprintf('%s:invalidOptionValue', ap),...
                    'Value for option %s must be a structured array mapping attribute names to values',...
                    name);
            end
            GLOBAL_ATTRIBUTES = value;
        case 'outfilename'
            if ~ischar(value) || isempty(value)
                error(sprintf('%s:invalidOptionValue', app),...
                    'Value for option %s must be a string specifying the filename to write',...
                    name);
            end
            outFile = value;
        case 'outdirectory'
            if ~ischar(value) || isempty(value) || ~isdir(value)
                error(sprintf('%s:invalidOptionValue', app),...
                    'Value for option %s must be a string specifying a valid directory to write',...
                    name);
            end
            OUT_DIR = value;
        otherwise
            error(sprintf('%s:invalidOption', app),...
                'Invalid option specified: %s',...
                name);
    end
end

% We need the template file
NC_TEMPLATE = 'rtofsVirtualGliderFlatNc.nc4.nc';
if ~exist(NC_TEMPLATE, 'file')
    fprintf(2,...
        '%s:ncTemplateNotFound: The NetCDF template %s could not be found\n',...
        app,...
        NC_TEMPLATE);
    return;
end

% Grab the template info file as a structured array
try
    nci = ncinfo(NC_TEMPLATE);
catch ME
    fprintf(2,...
        '%s:%s: %s\n',...
        app,...
        ME.identifer,...
        ME.message);
    return;
end

% Get the list of variables in the template
NC_VARS = {nci.Variables.Name}';
PROFILE_VARS = {pStruct.vars.ncVarName}';

% Make sure we have the REQUIRED_VARIABLES in PROFILE_VARS
if ~isequal(length(intersect(REQUIRED_NC_VARS, PROFILE_VARS)),length(REQUIRED_NC_VARS))
    fprintf(2,...
        '%s:missingRequiredVariable: pStruct is missing one or more required variables\n',...
        app);
    return;
end
% Make sure we have variables in PROFILE_VARS that are also in NC_VARS
VARS = intersect(NC_VARS, PROFILE_VARS);
if isempty(VARS)
    fprintf(2,...
        '%s:noVariablesFound: pStruct does not contain any valid NetCDF variables\n',...
        app);
    return;
end

% Create the filename
% Create the filename, if not specified
if isempty(outFile)
    outFile = fullfile(OUT_DIR,...
        sprintf('%s-%s-%s.nc', pStruct.meta.glider, MODEL, datestr(pStruct.meta.startDatenum, 'yyyymmddTHHMM')));
else
    ncP = fileparts(outFile);
    if ~isdir(ncP)
        warning(sprintf('%s:invalidDirectory', app),...
            'The specified output directory does not exist: %s\n',...
            ncP);
        outFile = '';
        return;
    end
end

% Delete the current file, if it exists and CLOBBER is set to true
if CLOBBER && exist(outFile, 'file')
    fprintf(1,...
        'Clobbering existing file: %s\n',...
        outFile);
    try
        delete(outFile);
    catch ME
        fprintf('%s:%s\n',...
            ME.identifier,...
            ME.message);
        return;
    end
end

% Add some specific global attributes
G_ATTS = {nci.Attributes.Name}';
[~,I] = ismember('title', G_ATTS);
if isequal(I,0)
    nci.Attributes(end+1).Name = 'title';
    I = length(nci.Attributes);
end
nci.Attributes(I).Value = sprintf('%s-%s-%s',...
    MODEL,...
    pStruct.meta.glider,...
    datestr(pStruct.meta.startDatenum, 'yyyymmddTHHMM'));
% Add new or overwrite existing global attributes if specified via the
% 'attributes' option
if ~isempty(GLOBAL_ATTRIBUTES)
end

% Template Dimensions
NC_DIMS = {nci.Dimensions.Name}';
% Handle dimension variables first (REQUIRED_NC_VARS)
% TIME dimension
[~,timeDI] = ismember('time', NC_DIMS);
[~,VI] = ismember('time', PROFILE_VARS);
timeLength = length(pStruct.vars(VI).data);
nci.Dimensions(timeDI).Length = timeLength;
nci.Dimensions(timeDI).Unlimited = false;

% traj_strlen dimension
[~,trajDI] = ismember('traj_strlen', NC_DIMS);
[~,VI] = ismember('trajectory', PROFILE_VARS);
% Confirm that pStruct.vars(VI).data is a string
if ~ischar(pStruct.vars(VI).data)
    fprintf(2,...
        '%s:invalidDataType: trajectory data must be a string specified as: glider-YYYYmmddTHHMM\n',...
        app);
    delete(outFile);
    outFile = '';
end
trajStrLength = length(pStruct.vars(VI).data);
nci.Dimensions(trajDI).Length = trajStrLength;
nci.Dimensions(trajDI).Unlimited = false;

% Update the nci.Variables.Dimensions length and unlimited settings
for v = 1:length(nci.Variables)
    
    if isempty(nci.Variables(v).Dimensions)
        continue;
    end
    
    varDims = {nci.Variables(v).Dimensions.Name}';
    
    [~,I] = ismember('time', varDims);
    if ~isequal(I,0)
        nci.Variables(v).Dimensions(I).Length = timeLength;
        nci.Variables(v).Dimensions(I).Unlimited = false;
    end
    
    [~,I] = ismember('traj_strlen', varDims);
    if ~isequal(I,0)
        nci.Variables(v).Dimensions(I).Length = trajStrLength;
        nci.Variables(v).Dimensions(I).Unlimited = false;
    end
        
end

% Create the file
try
    ncwriteschema(outFile, nci);
catch ME
    fprintf(2,...
        '%s:%s: %s\n',...
        app,...
        ME.identifier,...
        ME.message);
    outFile = '';
    return;
end

% Write the data to the file
for v = 1:length(NC_VARS)
    
    pVars = {pStruct.vars.ncVarName}';
    [~,I] = ismember(NC_VARS{v}, pVars);
    if isequal(I,0)
        if nci.Variables(v).Dimensions.Length < 1
            varData = repmat(nci.Variables(v).FillValue, 1, 1);
        else
            varData = repmat(nci.Variables(v).FillValue,...
                nci.Variables(v).Dimensions.Length,...
                1);
        end
        
        pStruct.vars(end+1) = struct('ncVarName', NC_VARS{v},...
            'data', varData);
        
        I = length(pStruct.vars);
    end
    
    % Re-define pVars in case it contains any new variables from the block
    % above
    pVars = {pStruct.vars.ncVarName}';
    
    % Convert any data for which the variable contains the string 'time'
    % and the data appears to be datenum.m
    if ~isempty(regexp(pVars{I}, 'time', 'once'))
        meanVal = mean(pStruct.vars(I).data(~isnan(pStruct.vars(I).data)));
        if meanVal < DATENUM_CUTOFF
            pStruct.vars(I).data = datenum2epoch(pStruct.vars(I).data);
        end
    end
      
    % Replace NaNs with _FillValues
    pStruct.vars(I).data(isnan(pStruct.vars(I).data)) = nci.Variables(v).FillValue;
    
    ncwrite(outFile, NC_VARS{v}, pStruct.vars(I).data);
    
end