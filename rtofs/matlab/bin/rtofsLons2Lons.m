function lons = rtofsLons2Lons(rtofs_lons, varargin)
%
% lons = rtofsLons2Lons(rtofs_lons, varargin)
%
% Converts longitude coordinates used by the NOAA/NCEP RTOFS (Real-Time Ocean 
% Forecasting System) model to longitudes with a valid range: -180 - +180.
% This model has a minimum longitude of 74.16E and a maximum longitude of
% 434.06227, so input longitudes > 180 are converted to their RTOFS grid
% equivalent.
%
% See also lons2RtofsLons
% ============================================================================
% $RCSfile$
% $Source$
% $Revision$
% $Date$
% $Author$
% ============================================================================
%

lons = [];

RTOFS_LON_MINIMUM = 74.16;
RTOFS_LON_MAXIMUM = 434.06227;

r = find(rtofs_lons > 180);

lons = rtofs_lons;

lons(r) = rtofs_lons(r) - RTOFS_LON_MAXIMUM + RTOFS_LON_MINIMUM;
