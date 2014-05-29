function DATAI = interpRtofs2GliderProfile(rtofsP, gliderProfile, varargin)

app = mfilename;
DATAI = [];

I_ROWS = size(rtofsP.Profiles(1).Data,1);
NUM_PROFILES = length(rtofsP.Profiles);
gps = cat(1,rtofsP.Profiles.LonLat);
[XI,YI,ZI] = meshgrid(gps(1:3,1)',...
    gps([7 4 1],2),...
    rtofsP.Profiles(1).Data(:,1));
DI = ZI;

% Make sure the glider profile is appropriately sized and has valid data
% points
if ~isequal(size(gliderProfile,2),3)
    return;
end

gliderProfile(any(isnan(gliderProfile),2),:) = [];
if size(gliderProfile,1) < 2
    return;
end

Z_COUNT = 1;
for r = 3:-1:1
    
    for c = 1:3
    
        DI(r,c,:) = rtofsP.Profiles(Z_COUNT).Data(:,2);
        
        Z_COUNT = Z_COUNT + 1;
        
    end
    
end

DATAI = gliderProfile(:,3);
DATAI(:,2) = interp3(XI, YI, ZI, DI,...
    gliderProfile(:,1), gliderProfile(:,2), gliderProfile(:,3));
