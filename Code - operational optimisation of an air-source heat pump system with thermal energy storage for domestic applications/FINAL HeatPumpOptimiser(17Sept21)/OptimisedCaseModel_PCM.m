function [ObjFunction,house,...
    TotOperCost,OPEX,...
    T,Qhp,Qeh,Qtotal,Whp,Wgrid,COP,COPsystem,...
    aThermostat,aSH,aDHW,...
    NtimesDHWdemandNotMet,NtimesSHdemandNotMet,DHWdemandNOTmet,...
    AverageSystemCOP,SelfConsumption,SelfSufficiency,DailyResults,X] = ...
    OptimisedCaseModel_PCM(x,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,tankVolumeSH,ICs,objectiveFunction)



% This function simulates the operation of a heat pump connected to a thermal storage device.

len = length(x);

% Optimisation variables
% ----------------------

chargeSpaceHeatingTank = x(1:len/3);                                        % binary: charging SH tank (on/off)
chargeDomesticHotWaterTank = x((len/3)+1:len*2/3) ;                         % binary: charging DHW tank (on/off)
heatOutputControl =  x((len*2/3)+1:len)  ;                                  % continous: heat pump + electric heater delivered power (W)

% Number of time steps
% --------------------

NstepsControl = length(chargeSpaceHeatingTank)    ;                         % number of times a control decision is made
NstepsInputs  = length(Ddhw);                                               % number of input timesteps
TimeResInputs = nDays * 24 * 60 * 60 / NstepsInputs ;                       % temporal resolution of inputs (s)

% Repeat control arrays for all model timesteps
% ---------------------------------------------

aSH     = repelem(chargeSpaceHeatingTank,NstepsInputs/NstepsControl)';      % binary: charging-tank (on/off)
aDHW     = repelem(chargeDomesticHotWaterTank,NstepsInputs/NstepsControl)'; % binary: charging-tank (on/off)
heatingPower  = repelem(heatOutputControl,NstepsInputs/NstepsControl)';     % continous: heat pump + electric heater delivered power (W)

% Allocating result matrices
% --------------------------

COP       = zeros(NstepsInputs,1);                                          % heat pump COP
Whp       = zeros(NstepsInputs,1);                                          % work input of heat pump (W)
Weh       = zeros(NstepsInputs,1);                                          % work input of electric heater (W)
Win       = zeros(NstepsInputs,1);                                          % work input of system (heat pump + electric heater) (W)
Wgrid     = zeros(NstepsInputs,1);                                          % imported electricity; if negative, electricity is exported (W)
Qhp       = zeros(NstepsInputs,1);                                          % heat output of heat pump (W)
Qeh       = zeros(NstepsInputs,1);                                          % heat output of electric heater (W)
Qtotal    = zeros(NstepsInputs,1);                                          % heat output of system (heat pump + electric heater) (W)
COPsystem = zeros(NstepsInputs,1);                                          % COP of system (heat pump + electric heater) (W)
OPEX      = zeros(NstepsInputs,1);                                          % operational cost of each time step (£)
DHWdemandNOTmet = zeros(NstepsInputs,1);                                    % DHW demand not met (kg/s)
nDHWdemandNOTmet = zeros(NstepsInputs,1);                                   % binary - 0 if demand is met, 1 if demand is NOT met
aThermostat = zeros(NstepsInputs,1);                                        % binary - 1 if SH is ON, 0 if OFF
NtimesSHdemandNotMet = 0 ;                                                  % number of times the internal space temperature falls below limit
% timer = 0 ; 

% SH boundaries
% -------------

TminSpace = 18 + 273.15 ;                                                   % switch on space heating whenever the temperature goes below 19 C
TmaxSpace = 22 + 273.15;                                                    % switch off space heating whenever the temperature goes above 21 C

% House thermal model set-up
% --------------------------

BCs.Tmains = 10 + 273.15 ;
BCs.TrequestDHW = 43 + 273.15 ;
house = householdThermalModel_PCMStore(tankVolumeDHW,tankVolumeSH,BCs) ;

% Time horizon and resolution (according to inputs)
% ---------------------------
time = linspace(0,nDays*24*60*60,length(aSH));

% TEMPERATURES
% 1 = Primary loop, 2 = Heat emitters, 3 = Internal space, 4 = Building envelope 
T = zeros(length(time),4) ;  

% MOLTEN FRACTIONS
% 5 = DHW PCM tank, 6 = SH PCM tank
X = zeros(length(time),2) ;

% Initial conditions
% ------------------

house.X(5) = ICs.fillingRatioPCM_DHW ;
house.X(6) = ICs.fillingRatioPCM_DHW ;


% Imposed internal temperature
house.X(3) = 20 + 273.15 ;

% Envelope temperature
house.X(4) = ( house.Gext .* Text(1) + house.Gint .* house.X(3) ) ./ (house.Gext + house.Gint) ;

% Heat-emitter temperature
house.X(2) = house.X(3) - house.Gint./house.Gem .* ( house.X(4) - house.X(3) ) ;

% Store initial solution
T(1,:) = house.X(1:4) ;
X(1,:) = house.X(5:6) ;

% Space heating is off unless requested from the thermostat
controls.thermostat = 0;


% Run thermal model
% -----------------

for n = 2:length(time)
    
    
    timeSpan = time(n) - time(n-1) ;
    
    % Hot-water demand (corrected to always provide water at 43 °C)
    demand.DHWmassFlowRate = Ddhw(n) ;
    
    % Check whether SH PCM tank is being charged
    controls.chargeSpaceHeatingTank = aSH(n);
    
    % Check whether DHW PCM tank is being charged
    controls.chargeDomesticHotWaterTank = aDHW(n);
    
    % Check the heat pump power if tank is being charged
    controls.heatingPower = heatingPower(n);
    
    % Space heating control from thermostat
    if house.X(3) < TminSpace
        controls.thermostat = 1;      
        
    elseif house.X(3) > TmaxSpace
        controls.thermostat = 0;  
                
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Let's avoid the use of the electric heater if it's not neccesary (added in August 2021)
    if house.X(3) > 16 + 273.15
        house.Qhp = controls.heatingPower;
        house = house.HP_performance_part_load();
        if isnan(house.COP)
            controls.chargeSpaceHeatingTank = 0;
%             controls.thermostat = 0; 
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Irradiance and temperature inputs
    irradiance.globalHorizontalSolarIrradiance = GlobHorIrr(n);
    BCs.Tamb = Text(n) ;
    BCs.Tmains = 10 + 273.15 ;
    BCs.TrequestDHW = 43 + 273.15 ;
      
    % Run house thermal model
    house = house.predictThermalState(timeSpan,controls,demand,irradiance,BCs);  
    
   
    
    % check if there is hot water available. If not, the tank does not  provide
    % the required heat...:(
    if demand.DHWmassFlowRate > 0 && house.mDotDHW == 0 
        nDHWdemandNOTmet(n) = 1 ;
        DHWdemandNOTmet(n) = demand.DHWmassFlowRate;
    end
    

    
    % Cold internal temperature
    if house.X(3) < 16 + 273.15 
        NtimesSHdemandNotMet = NtimesSHdemandNotMet + 1; 
    end
    
    % Post-processing (calculate/store outputs)
    %==========================================
    
    % Space heating and tank-charging binaries
    aThermostat(n) = house.aT ;
    aSH(n) = house.aSH ;
    aDHW(n) = house.aDHW ;

    % Temperatures of thermal model
    T(n,:) = house.X(1:4) ;
    
    % Tank molten fractions 
    X(n,:) = house.X(5:6) ;
    
    % Total heat produced
    Qeh(n) = house.Qeh;
    Qhp(n) = house.Qhp;
    Qtotal(n) = house.Qtotal;
    COP(n) = house.COP;
    
    % Work input required
    Weh(n) = Qeh(n);
    if COP(n) == 0
        Whp(n) = 0;
    else
        Whp(n) = Qhp(n) / COP(n);
    end
    Win(n) = Whp(n) + Weh(n);
    
    % System (heat pump + electric heater) COP
    if Win(n) ~= 0
        COPsystem(n) = Qtotal(n)./Win(n);
    end
    
    % Imported electricity
    Wgrid(n) = Win(n) - Wpv(n) ;  % if negative, electricity is exported (W)
    
    % Energy bills
    if Wgrid(n) >= 0
        OPEX(n) = Cimp(n) * (TimeResInputs/3600) * (Wgrid(n)/1000);
        
    elseif Wgrid(n) < 0
        OPEX(n) = Cexp(n) * (TimeResInputs/3600) * (Wgrid(n)/1000);
        
        % Let's assume we don't get paid for exporting
        OPEX(n) = 0;
    end
    
end

% Total operation cost for chosen time horizon
TotOperCost = sum(OPEX);

% Average system COP 
AverageSystemCOP = sum(Qtotal)/sum(Win);

% Proportion of electricity produced that is internally used (not exported)
SelfConsumption = 1 - abs(sum(Wgrid(Wgrid<0))/sum(Wpv));

% Proportion of electricity required that is not imported
SelfSufficiency = 1 - abs(sum(Wgrid(Wgrid>0))/sum(Win));

% Number of times DHW demand is not met
NtimesDHWdemandNotMet = sum(nDHWdemandNOTmet);

% Penalties and bounds
%---------------

LocationDemandNotMet = find(DHWdemandNOTmet>0);
PenaltyLowerCost = zeros(length(LocationDemandNotMet),1);
PenaltyUpperCost = zeros(length(LocationDemandNotMet),1);

Win_LB = zeros(length(LocationDemandNotMet),1);
Win_UB = zeros(length(LocationDemandNotMet),1);
Qtotal_LB = zeros(length(LocationDemandNotMet),1);
Qtotal_UB = zeros(length(LocationDemandNotMet),1);

for k = 1:length(LocationDemandNotMet)
    Loc = LocationDemandNotMet(k);
    house = house.HP_performance_nominal();
    if ~isnan(house.COP)
        COPLoc= house.COP;
    else
        COPLoc = 1;
    end
    house.COP=0;
    house.Qhp=0;
        
    Win_LB(k) = DHWdemandNOTmet(Loc) * 4.18 * 10^3 * (43-10) * ...
        (1/1) ;
    Qtotal_LB(k) = Win_LB(k);
    
    Win_UB(k) = DHWdemandNOTmet(Loc) * 4.18 * 10^3 * (43-10) * ...
        (1/COPLoc);
    Qtotal_UB(k) = Win_UB(k) * COPLoc;
    
end

PenaltyLBCost = sum(PenaltyLowerCost);
PenaltyUBCost = sum(PenaltyUpperCost);

TotOperCostLB = TotOperCost + PenaltyLBCost;
TotOperCostUB = TotOperCost + PenaltyUBCost;

AverageSystemCOP_LB = (sum(Qtotal)+sum(Qtotal_LB))./(sum(Win)+sum(Win_LB));
AverageSystemCOP_UB = (sum(Qtotal)+sum(Qtotal_UB))./(sum(Win)+sum(Win_UB));

% Daily Results
%===================

DailyResults.HeatPumpOutputSH = sum((Qhp.*aSH) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.HeatPumpOutputDHW = sum((Qhp.*aDHW) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.HeatPumpOutputTot = DailyResults.HeatPumpOutputSH + DailyResults.HeatPumpOutputDHW;    % kWh/day

DailyResults.ElecHeatOutputSH = sum((Qeh.*aSH) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.ElecHeatOutputDHW = sum((Qeh.*aDHW) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.ElecHeatOutputTot = DailyResults.ElecHeatOutputSH + DailyResults.ElecHeatOutputDHW;    % kWh/day

DailyResults.TotalHeatOutput = DailyResults.HeatPumpOutputTot + DailyResults.ElecHeatOutputTot;

DailyResults.AverageSystemCOP = AverageSystemCOP;                                                          % £/day
DailyResults.AverageSystemCOP_LB = AverageSystemCOP_LB;
DailyResults.AverageSystemCOP_UB = AverageSystemCOP_UB;

DailyResults.OperCost = TotOperCost/nDays;                                                          % £/day
DailyResults.OperCostLB = TotOperCostLB/nDays;
DailyResults.OperCostUB = TotOperCostUB/nDays;

DailyResults.SpecificCost = TotOperCost/ (sum(Qtotal)* TimeResInputs /(60*60 * 1000));

DailyResults.NtimesDHWdemandNotMet = NtimesDHWdemandNotMet / nDays;
DailyResults.NtimesSHdemandNotMet = NtimesSHdemandNotMet / nDays;

DailyResults.ElecImported = sum(Wgrid(Wgrid>0))* TimeResInputs /(60*60 * 1000 *nDays );
DailyResults.ElecConsumption = sum(Win)* TimeResInputs /(60*60 * 1000 *nDays );

DailyResults.PercentageOfDemandMet = (DailyResults.TotalHeatOutput-((sum(DHWdemandNOTmet(DHWdemandNOTmet>0)* 4.18 * 10^3 * (43-10))* TimeResInputs /(60*60 * 1000))/nDays))/DailyResults.TotalHeatOutput;

% Objective function 
%===========================

switch objectiveFunction
    case 'TotOperCost'
        ObjFunction = TotOperCost;
    case 'AverageSystemCOP'
        ObjFunction = - AverageSystemCOP;
    case 'SelfConsumption'
        ObjFunction = - SelfConsumption;
    case 'SelfSufficiency'
        ObjFunction = - SelfSufficiency;
end


end