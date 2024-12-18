function [house,...
    TotOperCost,OPEX,...
    T,Qhp,Qeh,Qtotal,Whp,Wgrid,COP,COPsystem,...
    tankEnergy,coldWaterHeight,hotWaterMass,coldWaterMass,...
    aSH,aT,...
    NtimesDHWdemandNotMet,NtimesSHdemandNotMet,DHWdemandNOTmet,...
    AverageSystemCOP,SelfConsumption,SelfSufficiency,DailyResults] = ...
    BaseCaseTankModel(Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolume,ICs)

%This function simulates the operation of a heat pump connected to a DHW cylinder. 

% Number of time steps
% --------------------
NstepsInputs  = length(Ddhw);                            % number of input timesteps
TimeResInputs = nDays * 24 * 60 * 60 / NstepsInputs ;    % temporal resolution of inputs (s)

% Allocating result matrices
% --------------------------

COP       = zeros(NstepsInputs,1);         % heat pump COP
Whp       = zeros(NstepsInputs,1);         % work input of heat pump (W)
Weh       = zeros(NstepsInputs,1);         % work input of electric heater (W)
Win       = zeros(NstepsInputs,1);         % work input of system (heat pump + electric heater) (W)
Wgrid     = zeros(NstepsInputs,1);         % imported electricity; if negative, electricity is exported (W)
Qhp       = zeros(NstepsInputs,1);         % heat output of heat pump (W)
Qeh       = zeros(NstepsInputs,1);         % heat output of electric heater (W)
Qtotal    = zeros(NstepsInputs,1);         % heat output of system (heat pump + electric heater) (W)
COPsystem = zeros(NstepsInputs,1);         % COP of system (heat pump + electric heater) (W)
OPEX      = zeros(NstepsInputs,1);         % operational cost of each time step (£)
DHWdemandNOTmet = zeros(NstepsInputs,1);   % DHW demand not met (kg/s)
nDHWdemandNOTmet = zeros(NstepsInputs,1);  % binary - 0 if demand is met, 1 if demand is NOT met
aSH = zeros(NstepsInputs,1);               % binary - 1 if SH is ON, 0 if OFF
aT = zeros(NstepsInputs,1);                % binary - 1 if charging-tank is ON, 0 if OFF
hotWaterMass = zeros(NstepsInputs,1);      % hot water mass in tank (kg)
coldWaterMass = zeros(NstepsInputs,1);     % cold water mass in tank (kg)
NtimesSHdemandNotMet = 0 ;                 % number of times the internal space temperature falls below limit

% SH boundaries
% -------------

TminSpace = 18 + 273.15 ;    % switch on space heating whenever the temperature goes below 18 °C
TmaxSpace = 22 + 273.15;    % switch off space heating whenever the temperature goes above 22 °C

% House thermal model set-up
% --------------------------

house = householdThermalModel_DHWCylinder(ICs.fillingRatio,tankVolume) ;
house.T(5) = ICs.Thot ;
house.T(6) = ICs.Tcold ;

% house.HPhighTempSwitch = 0 ;

% Time horizon and resolution (according to inputs)
% ---------------------------
time = linspace(0,nDays*24*60*60,length(aT));

T = zeros(length(time),length(house.T)) ; % 1 = Primary loop, 2 = Heat emitters, 3 = Internal space, 4 = Building envelope, 5 = Water tank - hot side, 6 = Water tank - cold side
tankEnergy = zeros(length(time),1) ;

% Initial conditions
% ------------------

coldWaterHeight = zeros(length(time),1) ;
coldWaterHeight(1) = house.heightInterface ;
tankEnergy(1) = house.massWaterTankCold.*house.water.cp.*house.T(6) + ...
    house.massWaterTankHot.*house.water.cp.*house.T(5);

% Imposed internal temperature
house.T(3) = 20 + 273.15 ;

% Envelope temperature
house.T(4) = ( house.Gext .* Text(1) + house.Gint .* house.T(3) ) ./ (house.Gext + house.Gint) ;

% Heat-emitter temperature
house.T(2) = house.T(3) - house.Gint./house.Gem .* ( house.T(4) - house.T(3) ) ;

% Store initial solution
T(1,:) = house.T ;

% Space heating is off unless requested from the thermostat
controls.spaceHeating = 0;

% Tank-charging off unless half empty
controls.chargingTank  = 0 ;

% Heat pump power is off unless requested for space heating / tank-charging
controls.heatingPower = 0 ; 


% Run thermal model
% -----------------

for n = 2:length(time)
    
    
    timeSpan = time(n) - time(n-1) ;
    
    % Hot-water demand (corrected to always provide water at 43 °C)
    demand.DHWmassFlowRate = Ddhw(n) * (43-10)/(T(n-1,5)- (10 + 273.15)) ;
        
    % Space heating based on command from the thermostat
    if house.T(3) < TminSpace
        controls.spaceHeating = 1;
        house = house.HP_performance_nominal(Text(n));
        controls.heatingPower = house.Qhp; 
        if isnan(controls.heatingPower)
            controls.heatingPower = 3000;
        end
    elseif house.T(3) > TmaxSpace
        controls.spaceHeating = 0;
    else
        if controls.spaceHeating == 1
            % if we are above the minimum temperature, there is no need to use the
            % electric heater even if the heat pump is outside its operating
            % conditions
            house = house.HP_performance_nominal(Text(n));
            if ~isnan(house.Qhp)
                controls.spaceHeating = 1;
                controls.heatingPower = house.Qhp;
            else
                controls.spaceHeating = 0;
            end
        end
    end    
    
    % tank-charging control based on the state of the tank
    if strcmp(house.controlSignal,'needCharging') 
        
        % use heat pump at nominal power or electric heater if the heat pump is 
        % outside the operating conditions
        controls.chargingTank = 1;
        house = house.HP_performance_nominal(Text(n));
        controls.heatingPower = house.Qhp; 
        if isnan(controls.heatingPower)
            controls.heatingPower = 3000;
        end
       
    elseif strcmp(house.controlSignal,'tankFull')
        controls.chargingTank = 0;
    end          
        
    % check if there is hot water available. If not, the tank does not  provide
    % the required heat...:(
    if demand.DHWmassFlowRate > 0 && ...
            (house.T(5) < house.thresholdAvailableHotWater...
            || (demand.DHWmassFlowRate*timeSpan > house.massWaterTankHot))          
        nDHWdemandNOTmet(n) = 1 ;
        DHWdemandNOTmet(n) = demand.DHWmassFlowRate;
        demand.DHWmassFlowRate = 0 ;
    end
    
    % Irradiance and temperature inputs
    irradiance.globalHorizontalSolarIrradiance = GlobHorIrr(n);
    BCs.Tamb = Text(n) ;
    BCs.Tmains = 10 + 273.15 ;
    
    % Run house thermal model
    house = house.predictThermalState(timeSpan,controls,demand,irradiance,BCs);
    
    % Cold internal temperature
    if house.T(3) < 16 + 273.15 
        NtimesSHdemandNotMet = NtimesSHdemandNotMet + 1; 
    end
    
    % Post-processing (calculate/store outputs)
    %==========================================
    
    % Space heating and tank-charging binaries
    aSH(n) = house.aSH ;
    aT(n) = house.aT ;
    
    % Temperatures of thermal model
    T(n,:) = house.T ;
    
    % Hot-water tank cold water height and tank energy
    coldWaterHeight(n) = house.heightInterface ;
    tankEnergy(n) = house.massWaterTankCold.*house.water.cp.*house.T(6) + ...
        house.massWaterTankHot.*house.water.cp.*house.T(5);
    
    % hot and cold water mass in tank (kg)
    hotWaterMass(n) = house.massWaterTankHot;
    coldWaterMass(n) = house.massWaterTankCold;   
    
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
    house = house.HP_performance_nominal(Text(Loc));
    if ~isnan(house.COP)
        COPLoc= house.COP;
    else
        COPLoc = 1;
    end
    house.COP=0;
    house.Qhp=0;
        
    PenaltyLowerCost(k) = DHWdemandNOTmet(Loc) * 4.18 * 10^3 * (43-10) * ...
        (1/COPLoc) * (1/1000) * (TimeResInputs/3600) *  Cimp(Loc);
    
    PenaltyUpperCost(k) = DHWdemandNOTmet(Loc) * 4.18 * 10^3 * (43-10) * ...
        (1/1) * (1/1000) * (TimeResInputs/3600) *  Cimp(Loc);
    
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
DailyResults.HeatPumpOutputDHW = sum((Qhp.*aT) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.HeatPumpOutputTot = DailyResults.HeatPumpOutputSH + DailyResults.HeatPumpOutputDHW;    % kWh/day

DailyResults.ElecHeatOutputSH = sum((Qeh.*aSH) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.ElecHeatOutputDHW = sum((Qeh.*aT) * TimeResInputs /(60*60 * 1000))/nDays;              % kWh/day
DailyResults.ElecHeatOutputTot = DailyResults.ElecHeatOutputSH + DailyResults.ElecHeatOutputDHW;    % kWh/day

DailyResults.TotalHeatOutput = DailyResults.HeatPumpOutputTot + DailyResults.ElecHeatOutputTot;

DailyResults.AverageSystemCOP = AverageSystemCOP;                                                   % £/day
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

end