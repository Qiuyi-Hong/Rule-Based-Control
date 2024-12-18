function [GlobHorIrr,ExtNormIrr,DirNormIrr,DiffHorIrr,DirHorIrr,Longitude,Latitude,Country,Text,Cimp,Cexp,Days,Ddhw] =...
            chooseData(location,W,ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,nDays)

nSteps = length(WeatherOban.GlobHorIrr)* nDays/7;

if strcmp(location,'Oban')
    GlobHorIrr  = WeatherOban.GlobHorIrr(1:nSteps,W);       % global horizontal radiation (W/m2)
    ExtNormIrr  = WeatherOban.ExtNormIrr(1:nSteps,W);       % extraterrestrial direct normal radiation (W/m2) 
    DirNormIrr  = WeatherOban.DirNormIrr(1:nSteps,W);       % direct normal radiation (W/m2)
    DiffHorIrr  = WeatherOban.DiffHorIrr(1:nSteps,W);       % diffuse horizontal radiation (Wh/m2)
    DirHorIrr   = WeatherOban.DirHorIrr(1:nSteps,W);        % direct horizontal radiation (W/m2)  
    Longitude   = WeatherOban.Longitude;                    % local longitude (Celsius)
    Latitude    = WeatherOban.Latitude;                     % local latitude(Celsius)
    Country     = WeatherOban.Country;                      % country 
    Text        = WeatherOban.Text(1:nSteps,W) + 273.15;    % ambient temperature (K)
    Cimp        = ElecPriceUK(1:nSteps) / 100;              % import electricity price (£/kWh) 
    Cexp        = ElecPriceUK(1:nSteps) / 100;              % export electricity price (£/kWh)   
    Days        = WeatherOban.Days(:,W);                    % days of the year corresponding to chosen week

elseif strcmp(location,'Munich')
    GlobHorIrr  = WeatherMunich.GlobHorIrr(1:nSteps,W);     % global horizontal radiation (W/m2)
    ExtNormIrr  = WeatherMunich.ExtNormIrr(1:nSteps,W);     % extraterrestrial direct normal radiation (W/m2) 
    DirNormIrr  = WeatherMunich.DirNormIrr(1:nSteps,W);     % direct normal radiation (W/m2)
    DiffHorIrr  = WeatherMunich.DiffHorIrr(1:nSteps,W);     % diffuse horizontal radiation (Wh/m2)
    DirHorIrr   = WeatherMunich.DirHorIrr(1:nSteps,W);      % direct horizontal radiation (W/m2)  
    Longitude   = WeatherMunich.Longitude;                  % local longitude (Celsius)
    Latitude    = WeatherMunich.Latitude;                   % local latitude(Celsius)
    Country     = WeatherMunich.Country;                    % country 
    Text        = WeatherMunich.Text(1:nSteps,W) + 273.15;  % ambient temperature (K)
    Cimp        = ElecPriceGermany(1:nSteps) / 100;         % import electricity price (£/kWh) 
    Cexp        = ElecPriceGermany(1:nSteps) / 100;         % export electricity price (£/kWh) 
    Days        = WeatherMunich.Days(:,W);                  % days of the year corresponding to chosen week

end

Ddhw        = Ddhw(1:nSteps);                               % domestic hot water demand (LPM)

end

