% Dataset configuration ======================================================
DBDGROUP = '/home/kerfoot/sandbox/glider/deployments-test/2013/ru29-374/ru29-374_DbdGroup_qc0.mat';
IMAGERY_ROOT = '/home/kerfoot/sandbox/glider/deployments-test/2013/ru29-374/imagery/RTOFS';

% % % % DBDGROUP = '/home/kerfoot/sandbox/glider/deployments-test/2012/silbo-354/silbo-354_DbdGroup_qc0.mat';
% % % % IMAGERY_ROOT = '/home/kerfoot/sandbox/glider/deployments-test/2012/silbo-354/imagery/RTOFS';

IMAGERY = false;
% ============================================================================
if ~exist(DBDGROUP, 'file')
    fprintf(2,...
        'Glider dataset does not exist: %s\n',...
        DBDGROUP);
    return;
end
if ~isdir(IMAGERY_ROOT)
    fprintf(2,...
        'RTOFS imagery root does not exist: %s\n',...
        IMAGERY_ROOT);
    return;
end

% Create the figures for printing
if ~IMAGERY
    warning('IMAGERY variable is set to false: No imagery will be created.\n');
else
    if ~exist('fh', 'var') || ~ishandle(fh)
        [fh, uv_ax, gps_ax, temp_ax, salt_ax] = createRtofsAxes();
    end
end

% RTOFS forecasts root directory
RTOFS_ROOT = '/Users/kerfoot/datasets/RTOFS';
RTOFS_ROOT = '/home/coolgroup/RTOFS/forecasts/gliders/ru29-374';
% % % % RTOFS_ROOT = '/home/coolgroup/RTOFS/forecasts/gliders/silbo-354';
if ~isdir(RTOFS_ROOT)
    fprintf(2,...
        'RTOFS Forecast root does not exist: %s\n',...
        RTOFS_ROOT);
    return;
end
RTOFS_TEMPERATURE_TEMPLATE = '*%s_rtofs_glo_3dz_nowcast_daily_temp.nc4.nc';
RTOFS_SALINITY_TEMPLATE = '*%s_rtofs_glo_3dz_nowcast_daily_salt.nc4.nc';
RTOFS_U_TEMPLATE = '*%s_rtofs_glo_3dz_nowcast_daily_uvel.nc4.nc';
RTOFS_V_TEMPLATE = '*%s_rtofs_glo_3dz_nowcast_daily_vvel.nc4.nc';

% Load the DbdGroup
try
    fprintf(1,...
        'Loading DbdGroup: %s...',...
        DBDGROUP);
    load(DBDGROUP);
    fprintf(1,...
        'Loaded.\n');
catch ME
    error(ME.identifier,...
        ME.message);
end

% Process all segments
dgroup.newSegments = dgroup.segments;

% Calculate and add salinity
ctd = dgroup.toArray('sensors', {'sci_water_temp', 'sci_water_cond'});
ctd(:,end+1) = calculate_glider_salinity(ctd(:,4), ctd(:,3), ctd(:,2));
dgroup.addSensor(ctd(:,5), 'sea_water_salinity', 'PSU');

% Convert the DbdGroup to a profiles structure
sensors = {'drv_longitude',...
    'drv_latitude',...
    'sci_water_temp',...
    'sci_water_cond',...
    'sea_water_salinity',...
    }';

% % % % % p = dgroup.toProfiles('sensors', sensors);

rtofs_profiles = struct('meta', [],...
    'timestamp', [],...
    'depth', [],...
    'drv_longitude', [],...
    'drv_latitude', [],...
    'sci_water_temp',...
    'sea_water_salinity');

% Gather glider depth-averaged currents
uv = dgroup.toArray('sensors', {'m_final_water_vx', 'm_final_water_vy'});
uv(any(isnan(uv(:,[3 4])),2),:) = [];
dups = find(diff(uv(:,3)) == 0 | diff(uv(:,4)) == 0);
uv(dups+1,:) = [];

% Store the Dbd instance segment names in a variable to prevent the list
% from be regenerated each time we need it (dependent property)
dgroup_segments = dgroup.segments;
    
for d = 1:length(dgroup.newSegments)
    
    [Y,I] = ismember(dgroup.newSegments{d}, dgroup_segments);
    if ~Y
        fprintf(2,...
            'No Dbd instance found for segment: %s\n',...
            dgroup.newSegments{d});
        continue;
    end

    p = dgroup.dbds(I).toProfiles('sensors', sensors);
    
    for p_ind = 1:length(p)
        % Calculate the profile center time
        p_datenum = mean([p(p_ind).meta.startDatenum p(p_ind).meta.endDatenum]);
        if isnan(p_datenum)
            fprintf(2,...
                'Unknown profile time: Profile %0.0f\n',...
                p_ind);
            continue;
        end

        fprintf(1,...
            'Profile %0.0f: %s\n',...
            p_ind,...
            datestr(p_datenum, 'yyyy-mm-dd HH:MM:SS'));

        % Convert the profile center time to 'yyyymmdd' date string
        pts = datestr(p_datenum, 'yyyymmdd');

        % Create the RTOFS forecast directory location to search for forecasts
        rtofs_dir = fullfile(RTOFS_ROOT,...
            pts,...
            pts);

        % See if the directory exists
        if ~isdir(rtofs_dir)
            % Skip this profile if it doesn't
            fprintf(2,...
                'Profile %0.0f: No RTOFS forecast directory: %s\n',...
                p_ind,...
                rtofs_dir);
            continue;
        end

        % Display the RTOFS forecast location
        fprintf(1,...
            'RTOFS forecast location: %s\n',...
            rtofs_dir);

        % Check for the temperature forecast
        rtofs_temp = sprintf(RTOFS_TEMPERATURE_TEMPLATE,...
            pts);
        RTOFS_TEMP_NC = dir(fullfile(rtofs_dir, rtofs_temp));
        if isempty(RTOFS_TEMP_NC)
            fprintf(2,...
                'No RTOFS temperature forecast found!\n');
            continue;
        elseif length(RTOFS_TEMP_NC) > 1
            fprintf(2,...
                'Multiple RTOFS temperature forecasts found!\n');
            continue;
        end
        RTOFS_TEMP_NC = fullfile(rtofs_dir, RTOFS_TEMP_NC.name);

        % Check for the salinity forecast
        rtofs_salt = sprintf(RTOFS_SALINITY_TEMPLATE,...
            pts);
        RTOFS_SALT_NC = dir(fullfile(rtofs_dir, rtofs_salt));
        if isempty(RTOFS_SALT_NC)
            fprintf(2,...
                'No RTOFS salinity forecast found!\n');
            continue;
        elseif length(RTOFS_SALT_NC) > 1
            fprintf(2,...
                'Multiple RTOFS salinity forecasts found!\n');
            continue;
        end
        RTOFS_SALT_NC = fullfile(rtofs_dir, RTOFS_SALT_NC.name);

        % Check for the u velocity forecast
        rtofs_u = sprintf(RTOFS_U_TEMPLATE,...
            pts);
        RTOFS_U_NC = dir(fullfile(rtofs_dir, rtofs_u));
        if isempty(RTOFS_U_NC)
            fprintf(2,...
                'No RTOFS u velocity forecast found!\n');
            continue;
        elseif length(RTOFS_U_NC) > 1
            fprintf(2,...
                'Multiple RTOFS u velocity forecasts found!\n');
            continue;
        end
        RTOFS_U_NC = fullfile(rtofs_dir, RTOFS_U_NC.name);

        % Check for the u velocity forecast
        rtofs_v = sprintf(RTOFS_V_TEMPLATE,...
            pts);
        RTOFS_V_NC = dir(fullfile(rtofs_dir, rtofs_v));
        if isempty(RTOFS_V_NC)
            fprintf(2,...
                'No RTOFS v velocity forecast found!\n');
            continue;
        elseif length(RTOFS_V_NC) > 1
            fprintf(2,...
                'Multiple RTOFS v velocity forecasts found!\n');
            continue;
        end
        RTOFS_V_NC = fullfile(rtofs_dir, RTOFS_V_NC.name);

        % Calculate the mean lon/lat of the glider profile
        lon = mean(p(p_ind).drv_longitude);
        lat = mean(p(p_ind).drv_latitude);
        if isnan(lon) || isnan(lat)
            fprintf(2,...
                'Invalid/NaN profile gps.\n');
            continue;
        end

        % Retrieve the RTOFS bounding temperature profiles
        try
            rtofs_temp_p = findRtofsBoundingProfiles(RTOFS_TEMP_NC,...
                'temperature',...
                lat,...
                lon,...
                'dtimes', p_datenum);
        catch ME
            warning(ME.identifier,...
                ME.message);
            continue;
        end

        % Retrieve the RTOFS bounding salinity profiles
        try
            rtofs_salt_p = findRtofsBoundingProfiles(RTOFS_SALT_NC,...
                'salinity',...
                lat,...
                lon,...
                'dtimes', p_datenum);
        catch ME
            warning(ME.identifier,...
                ME.message);
            continue;
        end

        % Retrieve the RTOFS bounding u velocity profiles
        try
            rtofs_u_p = findRtofsBoundingProfiles(RTOFS_U_NC,...
                'u',...
                lat,...
                lon,...
                'dtimes', p_datenum);
        catch ME
            warning(ME.identifier,...
                ME.message);
            continue;
        end

        % Retrieve the RTOFS bounding v velocity profiles
        try
            rtofs_v_p = findRtofsBoundingProfiles(RTOFS_V_NC,...
                'v',...
                lat,...
                lon,...
                'dtimes', p_datenum);
        catch ME
            warning(ME.identifier,...
                ME.message);
            continue;
        end

        % Find the closest RTOFS profile to the specified glider location
        t_dist = nan(length(rtofs_temp_p.Profiles),1);
        s_dist = t_dist;
        % Temperature
        for i = 1:length(t_dist)
            latitudes = [lat; rtofs_temp_p.Profiles(i).LonLat(2)];
            longitudes = [lon; rtofs_temp_p.Profiles(i).LonLat(1)];
            t_dist(i) = gcdist([latitudes longitudes]);
        end
        % Salinity
        for i = 1:length(s_dist)
            latitudes = [lat; rtofs_salt_p.Profiles(i).LonLat(2)];
            longitudes = [lon; rtofs_salt_p.Profiles(i).LonLat(1)];
            s_dist(i) = gcdist([latitudes longitudes]);
        end

        [~,TI] = min(t_dist);
        [~,SI] = min(s_dist);

        if ~isequal(TI, SI)
            fprintf(2,...
                'The closest RTOFS temperature and salinity profiles are in different locations.\n');
            continue;
        end

        fprintf(1,...
            'Filling RTOFS profile element...\n');

        % Add the RTOFS profile metadata
        [~,nc_segment] = fileparts(RTOFS_TEMP_NC);
        rtofs_profiles(end+1).meta = struct('glider', ['rtofs-' p(p_ind).meta.glider],...
            'filename', nc_segment,...
            'filetype', 'nc',...
            'the8x3_filename', pts,...
            'startDatenum', p_datenum,...
            'endDatenum', p_datenum,...
            'startTime', datestr(p_datenum, 'yyyy-mm-dd HH:MM:SS'),...
            'endTime', datestr(p_datenum, 'yyyy-mm-dd HH:MM:SS'),...
            'lonLat', rtofs_temp_p.Profiles(TI).LonLat);
        
        
        % Use the maximum glider profile depth to figure out which rows of
        % RTOFS to include
        z_rows = find(rtofs_temp_p.Profiles(TI).Data(:,1) <= max(p(p_ind).depth));
        
        % Add the RTOFS timestamp
        rtofs_profiles(end).timestamp = repmat(p_datenum, length(z_rows), 1);
        
        % Add the RTOFS temperature depths values
        rtofs_profiles(end).depth = rtofs_temp_p.Profiles(TI).Data(z_rows,1);
        
        % Add the RTOFS LonLat values
% % % % %         num_rows = length(rtofs_profiles(end).depth);
        rtofs_profiles(end).drv_longitude =...
            repmat(rtofs_temp_p.Profiles(TI).LonLat(1), length(z_rows), 1);
        rtofs_profiles(end).drv_latitude =...
            repmat(rtofs_temp_p.Profiles(TI).LonLat(2), length(z_rows), 1);

        % Add the RTOFS potential temperature values
        rtofs_profiles(end).sci_water_temp = rtofs_temp_p.Profiles(TI).Data(z_rows,2);

        % Add the RTOFS salinity values
        rtofs_profiles(end).sea_water_salinity = rtofs_salt_p.Profiles(SI).Data(z_rows,2);

        % Calculate density and add it
        rtofs_profiles(end).sea_water_density = sw_dens(rtofs_profiles(end).sea_water_salinity,...
            rtofs_profiles(end).sci_water_temp,...
            rtofs_profiles(end).depth);
        
        % Add the u profile
        rtofs_profiles(end).u = rtofs_u_p.Profiles(SI).Data(z_rows,2);

        % Add the v profile
        rtofs_profiles(end).v = rtofs_v_p.Profiles(SI).Data(z_rows,2);

        
        if IMAGERY
            fprintf(1,...
                'Plotting diagnostic plots...\n');
        %     keyboard;

            % Plot diagnostic imagery
            cla(gps_ax);
            rtofs_gps = cat(1, rtofs_temp_p.Profiles.LonLat);
            % Plot the bounding profile positions
            plot(gps_ax,...
                rtofs_gps(:,1), rtofs_gps(:,2),...
                'Marker', 'x',...
                'Color', 'k',...
                'MarkerSize', 15,...
                'LineStyle', 'None',...
                'LineWidth', 1);
            plot(gps_ax,...
                lon, lat,...
                'Marker', 'o',...
                'MarkerFaceColor', 'r',...
                'MarkerEdgeColor', 'k',...
                'Markersize', 15,...
                'LineStyle', 'None',...
                'LineWidth', 1);
            % Label the glider profile marker with the distance from the closest RTOFS
            % profiles
            axes(gps_ax);
            ht = text(lon, lat,...
                sprintf('%0.1f km', t_dist(TI)/1000),...
                'VerticalAlignment', 'Bottom',...
                'HorizontalAlignment', 'Center');
            axis(gps_ax, 'tight',...
                'square');

            cla(temp_ax);

            % Create the glider profile data array
            g_pro = [p(p_ind).sci_water_temp...
                p(p_ind).sea_water_salinity...
                p(p_ind).depth];
            % Create the RTOFS profile data array

            r_pro = [rtofs_profiles(end).sci_water_temp...
                rtofs_profiles(end).sea_water_salinity...
                rtofs_profiles(end).depth];

            % Maximum glider depth
            MAX_DEPTH = max(g_pro(:,3));

            % Plot the glider temperature profile
            g_pro(any(isnan(g_pro),2),:) = [];
            th = plot(temp_ax,...
                g_pro(:,1), g_pro(:,3),...
                'Marker', 'none',...
                'LineStyle', '-',...
                'Color', 'k',...
                'LineWidth', 2);
            % Plot the RTOFS temperature profile
            th(2) = plot(temp_ax,...
                r_pro(:,1), r_pro(:,3),...
                'Marker', 'none',...
                'LineStyle', '-',...
                'Color', 'r',...
                'LineWidth', 1);
            axis(temp_ax,...
                'tight');
            set(temp_ax,...
                'Ylim', [0 MAX_DEPTH]);
            xlabel(temp_ax,...
                'Temperature');
            t_leg = legend(temp_ax,...
                th, {'RU29', 'RTOFS'},...
                'Location', 'NorthWest');

            cla(salt_ax);

            % Plot the glider salinity profile
            th = plot(salt_ax,...
                g_pro(:,2), g_pro(:,3),...
                'Marker', 'none',...
                'LineStyle', '-',...
                'Color', 'k',...
                'LineWidth', 2);
            % Plot the RTOFS temperature profile
            th(2) = plot(salt_ax,...
                r_pro(:,2), r_pro(:,3),...
                'Marker', 'none',...
                'LineStyle', '-',...
                'Color', 'r',...
                'LineWidth', 1);
            axis(salt_ax,...
                'tight');
            set(salt_ax,...
                'Ylim', [0 MAX_DEPTH]);
            xlabel(salt_ax,...
                'Salinity');
            t_leg = legend(salt_ax,...
                th, {'RU29', 'RTOFS'},...
                'Location', 'NorthWest');

            % Find the closest glider-measured depth averaged current

            % Subtract the profile time (p_datenum) from the depth-averaged current
            % times
            t_diff = uv(:,1) - p_datenum;
            % Replace negative values with NaN since the depth-averaged current must
            % have been calculated AFTER the profile
            t_diff(t_diff <= 0) = NaN;
            if all(isnan(t_diff))
                I = [];
            else
                % Find the minimum delta time
                [~,I] = min(t_diff);
            end

            % Find the RTOFS depths that we want current vectors for
            r = find(rtofs_profiles(end).depth <= MAX_DEPTH);
            rtofs_uv = [rtofs_profiles(end).u(r) rtofs_profiles(end).v(r)];

            % Plot the RTOFS current vectors
            cla(uv_ax);
            cmap = jet(length(r));
            for ri = 1:length(r)
                h = quiver(uv_ax, 0, 0, rtofs_uv(ri,1), rtofs_uv(ri,2), 1);
                set(h, 'Color', cmap(ri,:));
            end

            % Plot the glider depth-averaged current on top of the rtofs currents
            if ~isempty(I)
                h = quiver(uv_ax, 0,0,uv(I,3),uv(I,4),1,'k');
                set(h, 'linewidth', 2);

                uv_title = ['Glider UV: ' datestr(uv(I,1), 'yyyy-mm-dd HH:MM')];
            else
                uv_title = 'No Glider UV';
            end

            % Create and place the title
            delete(findobj('Tag', 'topTitle'));
            t = mtit(['RU29 RTOFS Comparison: ' datestr(p_datenum, 'yyyy-mm-dd HH:MM UTC')]);
            set(t.ah,...
                'Tag', 'topTitle');

            % Title uv_ax with the datestring of the RTOFS current profile
            xlabel(uv_ax, uv_title);
            set(uv_ax, 'xaxislocation', 'top');

            print(gcf, '-dpng', '-r300', fullfile(IMAGERY_ROOT, ['ru29-rtofs_comparison_' datestr(p_datenum, 'yyyymmddTHHMM')]));
        end
        
    end
    
end

% Remove first element as it is empty
if length(rtofs_profiles) > 1
    rtofs_profiles(1) = [];
end
