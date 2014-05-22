function rtofs_lons = lons2RtofsLons(lons, varargin)
%
% rtofs_lons = lons2RtofsLon(lons, varargin)
%
% Converts longitudes (valid range: -180 - +180) to the longitude coordinates
% used by the NOAA/NCEP RTOFS (Real-Time Ocean Forecasting System) model.
% This model has a minimum longitude of 74.16E and a maximum longitude of
% 434.06227, so input longitudes less 74.16 are converted to their RTOFS grid
% equivalent.
%
% See also rtofsLons2Lons
% ============================================================================
% $RCSfile$
% $Source$
% $Revision$
% $Date$
% $Author$
% ============================================================================
%

rtofs_lons = [];

RTOFS_LON_MINIMUM = 74.16;
RTOFS_LON_MAXIMUM = 434.06227;

r = find(lons < RTOFS_LON_MINIMUM);

rtofs_lons = lons;

rtofs_lons(r) = RTOFS_LON_MAXIMUM - RTOFS_LON_MINIMUM + lons(r);
