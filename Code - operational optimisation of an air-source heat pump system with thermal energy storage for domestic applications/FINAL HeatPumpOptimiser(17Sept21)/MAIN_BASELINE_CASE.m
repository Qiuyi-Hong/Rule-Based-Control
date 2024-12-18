%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Optimisation study of a heat pump with thermal storage device %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%          MERCE-ICL           %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%  Andreas Olympios, Paul Sapin, James Freeman %%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Baseline Case
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% In the baseline case, the operation of the heat pump with the DHW cylinder
% are determined using a simplified control strategy based on temperature
% sensors. 
% The simplified control strategy used in this baseline case is the following: 

% We switch on space heating based on a thermostat, whenever the space
% temperature falls below a minimum level (e.g. 18 °C). We switch it off when 
% the space temperature rises above a maximum level (e.g. 22 °C).

% We switch on tank charging whenever the temperature of the hot water at the top
% of the tank or the cold water at the bottom of the tank fall below a threshold 
% (e.g. 43 °C). We switch off tank charging when half of the water in the tank
% is above the threshold temperature (50 °C).

% Both space heating and tank charging happen with nominal heat pump power.
% In case the heat pump can not operate in the provided conditions, a back-up
% electric heater is used. Tank charging is given priority.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Initialisations and input data
%  ==============================

% Temporal resolution of inputs (seconds)
TimeResInputs   = 120 ;  

% Extract inputs and adjust according to chosen temporal resolution
[ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw] = ...
    readInputs(TimeResInputs) ;

% Plot inputs
% plotInputs(ElecPriceUK,WeatherOban,ElecPriceGermany,...
% WeatherMunich,Ddhw,TimeResInputs);

% Periods
Period{1} = 'hotSummer';
Period{2} = 'coldWinter';
Period{3} = 'typicalSpring';
Period{4} = 'typicalSummer';
Period{5} = 'typicalAutumn';
Period{6} = 'typicalWinter' ;

% Locations
Locations{1} = 'Oban' ;
Locations{2} = 'Munich';

% tank volume
tankVolume = 0.2;

%%  ====================

for iLocation = 1:2
    
    % Choose location
    location = Locations{iLocation} ;
    
    % Choose time horizon - max 7 days        
    nDays = 7 ;
        
    % Choose range of typical weeks
    range = 3:6;
    
    for typicalWeek = range
            
        if nDays == 7
            fprintf(['Baseline operation of a ',Period{typicalWeek},...
                ' week in ',location]) ;
            fprintf(['\n',...
                '=========================================================',...
                '\n \n']) ;
        elseif nDays == 1
            fprintf(['Baseline operation of a single day during a '...
                Period{typicalWeek},...
                ' week in ',location]) ;
            fprintf(['\n',...
                '=========================================================',...
                '\n \n']) ;
        else
            fprintf(['Baseline operation of ',num2str(nDays),' days during a '...
                Period{typicalWeek},...
                ' week in ',location]) ;
            fprintf(['\n',...
                '=========================================================',...
                '\n \n']) ;
        end
                  
        fprintf(['\n',...
            'Tank volume:',num2str(tankVolume*1000),' L']);
        
        % season
        Season = Period(typicalWeek);
        
        % Obtain irradiances, ambient temperature, location, electricity prices
        % and DHW demand for selected period
        [GlobHorIrr,ExtNormIrr,DirNormIrr,DiffHorIrr,DirHorIrr,Longitude,Latitude,...
            Country,Text,Cimp,Cexp,Days,Ddhw] = chooseData(location,typicalWeek,...
            ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,nDays);
        
        % PV system set-up(Specifications based on JA Solar JAM6(L)60-285/PR Monocrystalline PV modules)
        PV = PVSystemModel;
        
        % calculate tilt irradiance
        PV = PV.PredictTiltIrradiance(DirHorIrr,DirNormIrr,DiffHorIrr,ExtNormIrr,Longitude,Latitude,Country,Days,Season);
        GlobTiltIrr = PV.GlobalTiltIrradiance;
        
        % predict PV power
        PV = PV.PredictPower(GlobTiltIrr,Text);
        Wpv = PV.powerSystem;
        
        % Initial conditions
        ICs.fillingRatio = 0.5 ;
        ICs.Thot = 50 + 273.15 ;
        ICs.Tcold = 10 + 273.15 ;
        
        % Perform baseline operation
        [house,...
            TotOperCost,OPEX,...
            T,Qhp,Qeh,Qtotal,Whp,Wgrid,COP,COPsystem,...
            tankEnergy,coldWaterHeight,hotWaterMass,coldWaterMass,...
            aSH,aDHW,...
            NtimesDHWdemandNotMet,NtimesSHdemandNotMet,DHWdemandNOTmet,...
            AverageSystemCOP,SelfConsumption,SelfSufficiency,DailyResults] = ...
            BaseCaseTankModel(Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolume,ICs);
        
        % Record total operational cost
        totalOPEX = TotOperCost ;
        
        % Print main outputs
        fprintf('\n\nTotal operation cost without penalty (£/day) = %.2f',DailyResults.OperCost) ;
        fprintf('\nTotal operation cost lower bound (£/day) = %.2f',DailyResults.OperCostLB) ;
        fprintf('\nTotal operation cost upper bound (£/day) = %.2f',DailyResults.OperCostUB) ;
        fprintf('\n\nSystem COP without penalty = %.2f',DailyResults.AverageSystemCOP) ;
        fprintf('\nSystem COP lower bound = %.2f',DailyResults.AverageSystemCOP_LB) ;
        fprintf('\nSystem COP upper bound = %.2f',DailyResults.AverageSystemCOP_UB) ;
        fprintf('\n\nSpecific cost per unit of heat provided(£/kWh) = %.3f',DailyResults.SpecificCost) ;
        fprintf('\nTotal heat pump output (kWh/day) = %.2f',DailyResults.HeatPumpOutputTot) ;
        fprintf('\nTotal electric heater output (kWh/day) = %.2f',DailyResults.ElecHeatOutputTot) ;
        fprintf('\n\nNumber of times DHW demand not met = %.0f',NtimesDHWdemandNotMet);
        fprintf('\nNumber of times SH demand not met = %.0f',NtimesSHdemandNotMet);
        fprintf('\nSelf sufficiency = %.0f',SelfSufficiency*100);
        fprintf('\n\nElectricity consumption (kWh/day) = %.2f',DailyResults.ElecConsumption);
        fprintf(['\n','====================================================','\n\n']) ;       
            
        % Display time-resolved results
        plotOutputs_DHW(OPEX,COP,COPsystem,...
            Qhp,Qeh,Wgrid,Wpv,Cimp,GlobTiltIrr,Ddhw,...
            T,Text,tankEnergy,coldWaterHeight,...
            aSH,aDHW,TimeResInputs,nDays,DailyResults);
        
        Save workspace
        save([location,Period{typicalWeek},...
                                    '_8.5kWHeatPump','Baseline_',...
                                    'TankSize200L_','DHW_FINAL.mat']); 
   end
end
