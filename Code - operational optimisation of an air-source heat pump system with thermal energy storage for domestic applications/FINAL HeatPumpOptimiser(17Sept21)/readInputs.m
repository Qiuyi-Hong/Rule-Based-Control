function [ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw] = readInputs(TimeResInputs)

% This function reads all required data and modifies it according to the
% chosen number of steps
load('OptimisationInputs','Demanddhw','ElectricityUK',...
    'ElectricityGermany','WeatherObanUK','WeatherMunichGermany');

timeHorizon = 7 * 24 * 60 * 60 ;  % total number of seconds (one week)
Nsteps = timeHorizon/(TimeResInputs); % number of timesteps

% Electricity prices  - UK and Germany
% =====================================================

ElecPriceUK = table2array(ElectricityUK(:,5));       % pence/kWh
ElecPriceGermany = table2array(ElectricityGermany(:,7));    % pence/kWh

intElecUK = length(ElecPriceUK)/Nsteps;           % interval required with this number of steps
intElecGermany = length(ElecPriceGermany)/Nsteps; % interval required with this number of steps

% Altering the resolution of the input data according to the chosen model resolution
if TimeResInputs >= timeHorizon/length(ElecPriceUK)
    ElecPriceUK = arrayfun(@(i) mean(ElecPriceUK(i:i+intElecUK-1)),...
                            1:intElecUK:length(ElecPriceUK)-intElecUK+1)';
else
    ElecPriceUK = interp1(1:length(ElecPriceUK), ElecPriceUK,...
                            linspace(1, length(ElecPriceUK), Nsteps), 'previous')';
end

if TimeResInputs >= timeHorizon/length(ElecPriceGermany)
    ElecPriceGermany = arrayfun(@(i) mean(ElecPriceGermany(i:i+intElecGermany-1)),...
                            1:intElecGermany:length(ElecPriceGermany)-intElecGermany+1)';
else
    ElecPriceGermany = interp1(1:length(ElecPriceGermany), ElecPriceGermany,...
                            linspace(1, length(ElecPriceGermany), Nsteps), 'previous')';
end


% Oban Weather
% ================================

% Collecting data. Columns represent(in this order): hot summer, cold winter...
% typical spring, typical summer, typical autumn, typical winter

% Days of the year corresponding to inputs
WeatherOban. Days = [163:1:169; 11:1:17; 88:1:94; 135:1:141; 295:1:301; 305:1:311]';

% (1) Ambient temperature (°C)
WeatherObanDat.Text =          [WeatherObanUK.HotSummer.Var6  WeatherObanUK.ColdWinter.Var6...
                                WeatherObanUK.TypicalSpring.Var6  WeatherObanUK.TypicalSummer.Var6...
                                WeatherObanUK.TypicalAutumn.Var6  WeatherObanUK.TypicalWinter.Var6];  
% (2) Extraterrestrial direct normal radiation (Wh/m2)                            
WeatherObanDat.ExtNormIrr =    [WeatherObanUK.HotSummer.Var11 WeatherObanUK.ColdWinter.Var11...
                                WeatherObanUK.TypicalSpring.Var11 WeatherObanUK.TypicalSummer.Var11...
                                WeatherObanUK.TypicalAutumn.Var11 WeatherObanUK.TypicalWinter.Var11]; 
% (3) Global horizontal radiation (Wh/m2)                            
WeatherObanDat.GlobHorIrr =    [WeatherObanUK.HotSummer.Var13 WeatherObanUK.ColdWinter.Var13...
                                WeatherObanUK.TypicalSpring.Var13 WeatherObanUK.TypicalSummer.Var13...
                                WeatherObanUK.TypicalAutumn.Var13 WeatherObanUK.TypicalWinter.Var13]; 
% (4) Direct normal radiation (Wh/m2)                      
WeatherObanDat.DirNormIrr =    [WeatherObanUK.HotSummer.Var14 WeatherObanUK.ColdWinter.Var14...
                                WeatherObanUK.TypicalSpring.Var14 WeatherObanUK.TypicalSummer.Var14...
                                WeatherObanUK.TypicalAutumn.Var14 WeatherObanUK.TypicalWinter.Var14]; 
% (5) Diffuse horizontal radiation (Wh/m2)                            
WeatherObanDat.DiffHorIrr =    [WeatherObanUK.HotSummer.Var15 WeatherObanUK.ColdWinter.Var15...
                                WeatherObanUK.TypicalSpring.Var15 WeatherObanUK.TypicalSummer.Var15...
                                WeatherObanUK.TypicalAutumn.Var15 WeatherObanUK.TypicalWinter.Var15]; 
% (6) Direct horiontal radiation (Wh/m2)
WeatherObanDat.DirHorIrr  =    WeatherObanDat.GlobHorIrr - WeatherObanDat.DiffHorIrr;

% interval required with this number of steps
intWeatherOban = length(WeatherObanDat.Text)/Nsteps; 

% Altering the resolution of the input data according to the chosen model resolution
if TimeResInputs >= timeHorizon/length(WeatherObanDat.Text)
    for k = 1:6
        WeatherOban.Text(:,k)       = arrayfun(@(i) mean(WeatherObanDat.Text(i:i+intWeatherOban-1,k)),...
                                        1:intWeatherOban:length(WeatherObanDat.Text)-intWeatherOban+1)';
        WeatherOban.ExtNormIrr(:,k) = arrayfun(@(i) mean(WeatherObanDat.ExtNormIrr(i:i+intWeatherOban-1,k)),...
                                        1:intWeatherOban:length(WeatherObanDat.ExtNormIrr)-intWeatherOban+1)';
        WeatherOban.GlobHorIrr(:,k) = arrayfun(@(i) mean(WeatherObanDat.GlobHorIrr(i:i+intWeatherOban-1,k)),...
                                        1:intWeatherOban:length(WeatherObanDat.GlobHorIrr)-intWeatherOban+1)';
        WeatherOban.DirNormIrr(:,k) = arrayfun(@(i) mean(WeatherObanDat.DirNormIrr(i:i+intWeatherOban-1,k)),...
                                        1:intWeatherOban:length(WeatherObanDat.DirNormIrr)-intWeatherOban+1)';
        WeatherOban.DiffHorIrr(:,k) = arrayfun(@(i) mean(WeatherObanDat.DiffHorIrr(i:i+intWeatherOban-1,k)),...
                                        1:intWeatherOban:length(WeatherObanDat.DiffHorIrr)-intWeatherOban+1)';
        WeatherOban.DirHorIrr(:,k)  = arrayfun(@(i) mean(WeatherObanDat.DirHorIrr(i:i+intWeatherOban-1,k)),...
                                        1:intWeatherOban:length(WeatherObanDat.DirHorIrr)-intWeatherOban+1)';
    end
else
    WeatherOban.Text =       interp1(1:length(WeatherObanDat.Text),WeatherObanDat.Text,...
                                        linspace(1, length(WeatherObanDat.Text), Nsteps), 'linear');
    WeatherOban.ExtNormIrr = interp1(1:length(WeatherObanDat.ExtNormIrr),WeatherObanDat.ExtNormIrr,...
                                        linspace(1, length(WeatherObanDat.ExtNormIrr), Nsteps), 'linear');
    WeatherOban.GlobHorIrr = interp1(1:length(WeatherObanDat.GlobHorIrr),WeatherObanDat.GlobHorIrr,...
                                        linspace(1, length(WeatherObanDat.GlobHorIrr), Nsteps), 'linear');
    WeatherOban.DirNormIrr = interp1(1:length(WeatherObanDat.DirNormIrr),WeatherObanDat.DirNormIrr,...
                                        linspace(1, length(WeatherObanDat.DirNormIrr), Nsteps), 'linear');
    WeatherOban.DiffHorIrr = interp1(1:length(WeatherObanDat.DiffHorIrr),WeatherObanDat.DiffHorIrr,...
                                        linspace(1, length(WeatherObanDat.DiffHorIrr), Nsteps), 'linear');
    WeatherOban.DirHorIrr  = interp1(1:length(WeatherObanDat.DirHorIrr),WeatherObanDat.DirHorIrr,...
                                        linspace(1, length(WeatherObanDat.DirHorIrr), Nsteps), 'linear');
end

% Country, latitude and longitude
WeatherOban.Country = "UK"; 
WeatherOban.Latitude = 56.4; %Latitude
WeatherOban.Longitude = -5.5; %Longitude



% Munich Weather
% =======================================

% Collecting data. Columns represent(in this order): hot summer, cold winter...
% typical spring, typical summer, typical autumn, typical winter

% Days of the year corresponding to inputs
WeatherMunich. Days =  [203:1:209; 43:1:49; 91:1:97; 196:1:202; 295:1:301; 8:1:14]';

%(1) Ambient temperature (°C)
WeatherMunichDat.Text       =  [WeatherMunichGermany.HotSummer.Var6  WeatherMunichGermany.ColdWinter.Var6...
                                WeatherMunichGermany.TypicalSpring.Var6  WeatherMunichGermany.TypicalSummer.Var6...
                                WeatherMunichGermany.TypicalAutumn.Var6  WeatherMunichGermany.TypicalWinter.Var6];  
% (2) Extraterrestrial direct normal radiation (Wh/m2)                            
WeatherMunichDat.ExtNormIrr =  [WeatherMunichGermany.HotSummer.Var11 WeatherMunichGermany.ColdWinter.Var11...
                                WeatherMunichGermany.TypicalSpring.Var11 WeatherMunichGermany.TypicalSummer.Var11...
                                WeatherMunichGermany.TypicalAutumn.Var11 WeatherMunichGermany.TypicalWinter.Var11]; 
% (3) Global horizontal radiation (Wh/m2)                           
WeatherMunichDat.GlobHorIrr =  [WeatherMunichGermany.HotSummer.Var13 WeatherMunichGermany.ColdWinter.Var13...
                                WeatherMunichGermany.TypicalSpring.Var13 WeatherMunichGermany.TypicalSummer.Var13...
                                WeatherMunichGermany.TypicalAutumn.Var13 WeatherMunichGermany.TypicalWinter.Var13]; 
% (4) Direct normal radiation (Wh/m2)                            
WeatherMunichDat.DirNormIrr =  [WeatherMunichGermany.HotSummer.Var14 WeatherMunichGermany.ColdWinter.Var14...
                                WeatherMunichGermany.TypicalSpring.Var14 WeatherMunichGermany.TypicalSummer.Var14...
                                WeatherMunichGermany.TypicalAutumn.Var14 WeatherMunichGermany.TypicalWinter.Var14]; 
% (5) Diffuse horizontal radiation (Wh/m2)                            
WeatherMunichDat.DiffHorIrr =  [WeatherMunichGermany.HotSummer.Var15 WeatherMunichGermany.ColdWinter.Var15...
                                WeatherMunichGermany.TypicalSpring.Var15 WeatherMunichGermany.TypicalSummer.Var15...
                                WeatherMunichGermany.TypicalAutumn.Var15 WeatherMunichGermany.TypicalWinter.Var15]; 
% (6) Direct horiontal radiation (Wh/m2)                           
WeatherMunichDat.DirHorIrr  =  WeatherMunichDat.GlobHorIrr - WeatherMunichDat.DiffHorIrr;

% interval required with this number of steps
intWeatherMunich = length(WeatherMunichDat.Text)/Nsteps; 

% Altering the resolution of the input data according to the chosen model resolution
if TimeResInputs >= timeHorizon/length(WeatherMunichDat.Text)
    for k =1:6
        WeatherMunich.Text(:,k)       = arrayfun(@(i) mean(WeatherMunichDat.Text(i:i+intWeatherMunich-1,k)),...
                                            1:intWeatherMunich:length(WeatherMunichDat.Text)-intWeatherMunich+1)';
        WeatherMunich.ExtNormIrr(:,k) = arrayfun(@(i) mean(WeatherMunichDat.ExtNormIrr(i:i+intWeatherMunich-1,k)),...
                                            1:intWeatherMunich:length(WeatherMunichDat.ExtNormIrr)-intWeatherMunich+1)';
        WeatherMunich.GlobHorIrr(:,k) = arrayfun(@(i) mean(WeatherMunichDat.GlobHorIrr(i:i+intWeatherMunich-1,k)),...
                                            1:intWeatherMunich:length(WeatherMunichDat.GlobHorIrr)-intWeatherMunich+1)';
        WeatherMunich.DirNormIrr(:,k) = arrayfun(@(i) mean(WeatherMunichDat.DirNormIrr(i:i+intWeatherMunich-1,k)),...
                                            1:intWeatherMunich:length(WeatherMunichDat.DirNormIrr)-intWeatherMunich+1)';
        WeatherMunich.DiffHorIrr(:,k) = arrayfun(@(i) mean(WeatherMunichDat.DiffHorIrr(i:i+intWeatherMunich-1,k)),...
                                            1:intWeatherMunich:length(WeatherMunichDat.DiffHorIrr)-intWeatherMunich+1)';
        WeatherMunich.DirHorIrr(:,k)  = arrayfun(@(i) mean(WeatherMunichDat.DirHorIrr(i:i+intWeatherMunich-1,k)),...
                                            1:intWeatherMunich:length(WeatherMunichDat.DirHorIrr)-intWeatherMunich+1)';
    end
else
    WeatherMunich.Text       = interp1(1:length(WeatherMunichDat.Text),WeatherMunichDat.Text,...
                                            linspace(1, length(WeatherMunichDat.Text), Nsteps), 'linear');
    WeatherMunich.ExtNormIrr = interp1(1:length(WeatherMunichDat.ExtNormIrr),WeatherMunichDat.ExtNormIrr,...
                                            linspace(1, length(WeatherMunichDat.ExtNormIrr), Nsteps), 'linear');
    WeatherMunich.GlobHorIrr = interp1(1:length(WeatherMunichDat.GlobHorIrr),WeatherMunichDat.GlobHorIrr,...
                                            linspace(1, length(WeatherMunichDat.GlobHorIrr), Nsteps), 'linear');
    WeatherMunich.DirNormIrr = interp1(1:length(WeatherMunichDat.DirNormIrr),WeatherMunichDat.DirNormIrr,...
                                            linspace(1, length(WeatherMunichDat.DirNormIrr), Nsteps), 'linear');
    WeatherMunich.DiffHorIrr = interp1(1:length(WeatherMunichDat.DiffHorIrr),WeatherMunichDat.DiffHorIrr,...
                                            linspace(1, length(WeatherMunichDat.DiffHorIrr), Nsteps), 'linear');
    WeatherMunich.DirHorIrr  = interp1(1:length(WeatherMunichDat.DirHorIrr),WeatherMunichDat.DirHorIrr,...
                                            linspace(1, length(WeatherMunichDat.DirHorIrr), Nsteps), 'linear');
end

%Country, latitude and longitude
WeatherMunich.Country = "Germany"; 
WeatherMunich.Latitude = 48.1; %Latitude
WeatherMunich.Longitude = 11.6; %Longitude

%% Domestic hot water demand
Ddhw = table2array(Demanddhw(:,2:8));   % volume flowrate (LPM at 43 °C
Ddhw = Ddhw(:);
Ddhw  = (Ddhw/ (1000 * 60)) * 997 ;     % mass flowrate(kg/s)

% interval required with this number of steps
intDdhw = length(Ddhw)/Nsteps;

% Altering the resolution of the input data according to the chosen model resolution
if TimeResInputs >= timeHorizon/length(Ddhw)
    Ddhw = arrayfun(@(i) mean(Ddhw(i:i+intDdhw-1)),1:intDdhw:length(Ddhw)-intDdhw+1)';
else
    Ddhw = interp1(1:length(Ddhw), Ddhw, linspace(1, length(Ddhw), Nsteps), 'linear')';
end

%get fast fourier transforms
% tWeather = linspace(1,length(WeatherObanDat.Text(:,1)),length(WeatherObanDat.Text(:,1)));
% [f,signalPower] = Fourier(tWeather,WeatherObanDat.Text(:,1));
% figure();
% loglog(f,signalPower)
% title('FFT - Text'); 
% [f,signalPower] = Fourier(tWeather,WeatherObanDat.GlobHorIrr(:,1));
% figure();
% loglog(f,signalPower)
% title('FFT - Irr'); 
% get fast fourier transforms
% tDdhw = linspace(1,length(Ddhw),length(Ddhw));
% [f,signalPower] = Fourier(tDdhw,Ddhw);
% figure();
% loglog(f,signalPower)
% title('FFT - Ddhw'); 
% 
end
