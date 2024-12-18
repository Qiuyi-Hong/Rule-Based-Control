% Paul Sapin and Andreas Olympios
% 4 January 2021

classdef householdThermalModel_DHWCylinder
    
    properties
        
        % Set of temperatures (K)
        % -------------------
        % 1 = Primary loop
        % 2 = Heat emitters
        % 3 = Internal space
        % 4 = Building envelope
        % 5 = Water tank - hot side
        % 6 = Water tank - cold side
        
        T = [50 20 20 15 50 10] + 273.15 ;
        
        % Tank charging properties
        % -----------------------
        
        massWaterTankHot
        massWaterTankCold
        heightInterface
        thresholdAvailableHotWater = 43+273.15 ;
        thresholdTankFull = 50+273.15;
        
        % Boundary conditions
        % -------------------
        
        Tmains
        Tamb
        
        % Tank dimensions
        % ---------------
        
        tankVolume
        tankHeight
        tankDiameter = 50e-2 ;
        
        % Maximum time step size (s)
        % ----------------------
        
        maxTimeStepSize = 120 ;
        
        % A max for Tank charging and another one for the rest!
        
        % Water thermo-physical properties
        % --------------------------------
        water 
        
        % Nominal mass flowrates (kg/s)
        % ----------------------
        
        % Primary loop
        VdotPL = 15 /60/1000 ; % 12 L/min --> m3/s
        mDotPL
        
        % Secondary loop
        VdotSL = 15 /60/1000 ; % 12 L/min --> m3/s
        mDotSL
        
        % Internal-space heat source
        % --------------------------
        
        Qint = 700 ; % = 350 W (lighting/appliances) + 350 W (people)
        
        % Primary-to-secondary loop HX effectiveness
        % ------------------------------------------
        
        epsilon = 0.8 ;
        
        % Thermal conductances
        % --------------------
        
        G               % (Conductance matrix)
        Gem = 150 ;
        Gint = 95 ;
        Gext = 840 ;
        Gvent = 60 ;
        Gloop = 1700 ;
        GtankLosses = 2 ;
        GpipeLoss = 2 ;
        
        % Thermal masses (inertia)
        % --------------
        
        C
        Cint = 1e7 ;
        Cenv = 2.5e7 ;
        Cem = 2e5 ;
        Cloop = 2e5 ;
        
        % Solar gain factors
        % ------------------
        
        ksEnv = 7.7 ; % m2
        ksInt = 0.7 ; % m2
        
        % Controls
        % --------
        
        aSH
        aT
        
        % Heat pump operating conditions and performance
        % ----------------------------------------------

        %Heat-pump heating power
        Qhp
        
        % Electric heater power
        Qeh
        
        % Total heating power provided
        Qtotal
        
        % Heat-pump COP
        COP
        
        % HP shutoff temperature threshold
        HPhighTempSwitch = 0
        
    end
    
    properties (Dependent)
        
        controlSignal
        hotWaterAvailability
        totalMassWater
        tankCrossArea
        
    end
    
    methods
        
        % Constructor method
        % ------------------
        
        function obj = householdThermalModel_DHWCylinder(fillingRatio,tankVolume)
            
            % Water thermo-physical properties (assmued constant at 20 C and 1 bar)
            obj.water.T = 20 + 273.15 ; % K
            obj.water.p = 1e5 ;         % Pa
            obj.water.cp = refpropm('C','T',obj.water.T,'P',obj.water.p / 1000,'water');
            obj.water.rho = refpropm('D','T',obj.water.T,'P',obj.water.p / 1000,'water');
            obj.water.thermCond = refpropm('L','T',obj.water.T,'P',obj.water.p / 1000,'water');
            
            % Mass flowrates
            obj.mDotPL = obj.VdotPL .* obj.water.rho ;
            obj.mDotSL = obj.VdotSL .* obj.water.rho ;
            
            % Infer tank dimensions and charging properties
            obj.tankVolume = tankVolume;
            obj.tankHeight = obj.tankVolume ./ obj.tankCrossArea ;
            obj.heightInterface = 1-fillingRatio ;
            heightRatio = obj.heightInterface./obj.tankHeight ;
            totalMassWater = obj.tankVolume .* obj.water.rho ;
            obj.massWaterTankCold = heightRatio .* totalMassWater ;
            obj.massWaterTankHot = (1-heightRatio) .* totalMassWater ;
            
            % Create thermal-conductance matrix (constant terms)
            obj.G = zeros(length(obj.T),length(obj.T)) ;
            obj.G(2,3) = obj.Gem ;
            obj.G(3,4) = obj.Gint ;
            obj.G(5,6) =  2.*obj.water.thermCond.*obj.tankCrossArea./obj.tankHeight ;
            
            % Thermal inertia (constant terms)
            obj.C = zeros(1,length(obj.T)) ;
            obj.C(1) = obj.Cloop ;
            obj.C(2) = obj.Cem ;
            obj.C(3) = obj.Cint ;
            obj.C(4) = obj.Cenv ;
            
        end
        
        % Get functions for dependent properties
        % --------------------------------------      
        function value = get.totalMassWater(obj)
            
            value = obj.tankVolume .* obj.water.rho ;
            
        end
        
        function value = get.tankCrossArea(obj)
            
            value = pi().*(obj.tankDiameter./2).^2 ;
            
        end
        

        function value = get.controlSignal(obj)
            
            % Simple control strategy: 
            % We switch on tank charging whenever the temperature of the hot water at the top
            % of the tank or the cold water at the bottom of the tank fall below a threshold (43 °C). 
            % We switch off tank charging when half of the water in the tank is above the
            % threshold temperature (50 °C).
            
            heightRatio = obj.heightInterface/obj.tankHeight ;
            
            if (obj.T(5) < obj.thresholdAvailableHotWater) || (obj.T(6) < obj.thresholdAvailableHotWater)
                value = 'needCharging' ;
            elseif (heightRatio <=0.5  && obj.T(5) >= obj.thresholdTankFull)
                value = 'tankFull' ;
            else
                value = [] ;
            end
         
        end
        
        
        % Linear model solving function
        % -----------------------------
        
        function obj = predictThermalState(obj,timeSpan,controls,demand,irradiance,BCs)
            
            % Space-heating binary (on/off)
            obj.aSH = controls.spaceHeating ;
            
            % Charging-tank binary (on/off)
            obj.aT = controls.chargingTank ;
            
            % Total HP+EH power if charging-tank is on
            obj.Qtotal = controls.heatingPower ;
            
            % Determine effective (feasible) operating conditions
            obj = obj.effectiveOperatingConditions(BCs.Tamb) ;
            
            % Calculating algorithm time step
            N = max([ceil(timeSpan./obj.maxTimeStepSize)+1 2]) ;
            
            % Create time vector
            time = linspace(0,timeSpan,N) ;
            dt = time(2) - time(1) ;
            
            % Extract DHW demand
            mDotDHW = demand.DHWmassFlowRate ;
            
            % Irradiance data
            Qsol = irradiance.globalHorizontalSolarIrradiance ;
            
            % Apply boundary conditions
            obj.Tamb = BCs.Tamb ;
            obj.Tmains = BCs.Tmains ;
            
            % Modify thermal-conductance matrix (constant terms)
            obj.G(1,2) = obj.aSH.*obj.mDotPL.*obj.water.cp  + ...
                obj.GpipeLoss ;
            
            for n = 2:length(time)
                
                % Predict tank charging properties
                predictedColdMass = obj.massWaterTankCold - ...
                    (obj.aT.*obj.mDotSL - mDotDHW).*dt ;
                predictedHeightInterface = ...
                    ( predictedColdMass ./ obj.water.rho ) ./ ...
                    obj.tankCrossArea ;
                predictedHeightRatio = predictedHeightInterface/obj.tankHeight ;
                
                if predictedHeightRatio < 0.05
                    
                    % Re-arrange cold and hot zones
                    newHeigthRatio = 0.95 ;
                    newMassWaterTankHot = (1-newHeigthRatio) .* obj.totalMassWater ;
                    newMassWaterTankCold = newHeigthRatio .* obj.totalMassWater ;
                    
                    % New cold water temperature
                    obj.T(6) =  ( ...
                        obj.massWaterTankCold .* obj.T(6) + ...
                        (obj.massWaterTankHot - newMassWaterTankHot) .* obj.T(5) ...
                        ) ./ ...
                        newMassWaterTankCold ;
                    
                    % New mass repartition
                    obj.massWaterTankCold = newMassWaterTankCold ;
                    obj.massWaterTankHot = newMassWaterTankHot ;
                    
                end
                
                % Mass balance
                obj.massWaterTankHot = obj.massWaterTankHot + ...
                    (obj.aT.*obj.mDotSL - mDotDHW) .* dt ;
                obj.massWaterTankCold = obj.massWaterTankCold - ...
                    (obj.aT.*obj.mDotSL - mDotDHW) .* dt ;
                
                % Estimate tank charging properties
                obj.heightInterface = ...
                    ( obj.massWaterTankCold ./ obj.water.rho ) ./ ...
                    obj.tankCrossArea ;
                heightRatio = obj.heightInterface./obj.tankHeight ;
                
                % Source terms
                Q = zeros(1,length(obj.T)) ;
                Q(3) = obj.ksInt.*Qsol + obj.Qint + obj.Gvent.*obj.Tamb ;
                Q(4) = obj.ksEnv.*Qsol + obj.Gext.*obj.Tamb ;
                Q(1) = obj.Qtotal ;
                
                % Time-dependent thermal masses
                obj.C(5) = obj.massWaterTankHot .* obj.water.cp ;
                obj.C(6) = obj.massWaterTankCold .* obj.water.cp ;
                
                % Time-dependant thermal conductances
                obj.G(4,5) = (1-heightRatio) .* obj.GtankLosses ;
                obj.G(4,6) = heightRatio .* obj.GtankLosses ;
                
                % Symmetric maxtrix build
                fullG = obj.G + obj.G' ;
                
                % A-matrix build
                A = zeros(length(obj.T),length(obj.T)) ;
                B = zeros(1,length(obj.T)) ;
                
                for i = 1:length(obj.T)
                    for j = 1:length(obj.T)
                        A(i,j) = (i==j).*( obj.C(i)./dt + sum(fullG(i,:)) ) - ...
                            (i~=j).*fullG(i,j) ;
                    end
                    B(i) = obj.C(i).*obj.T(i)./dt + Q(i) ;
                end
                clear fullG
                
                
                % Non-symmetric explicit terms
                
                A(3,3) = A(3,3) +obj.Gvent ;
                
                A(4,4) = A(4,4) + obj.Gext ;
                
                A(1,1) = A(1,1) + obj.aT.*obj.epsilon.*...
                    min(obj.mDotPL,obj.mDotSL) .* obj.water.cp ;
                A(1,6) = A(1,6) - obj.aT.*obj.epsilon.*...
                    min(obj.mDotPL,obj.mDotSL) .* obj.water.cp ;
                
                A(5,6) = A(5,6) - obj.aT.*obj.mDotSL.*obj.water.cp ;
                
                A(5,1) =  A(5,1) - obj.aT.*obj.epsilon.*...
                    min(obj.mDotPL,obj.mDotSL) .* obj.water.cp ;
                A(5,6) =  A(5,6) + obj.aT.*obj.epsilon.*...
                    min(obj.mDotPL,obj.mDotSL) .* obj.water.cp ;
                
                B(5) = B(5) - ...
                    obj.aT.*obj.mDotSL.*obj.water.cp.*obj.T(5) ;
                
                B(6) = B(6) +  ...
                    mDotDHW .* obj.water.cp .*(obj.Tmains-obj.T(6)) ;
                
                obj.T = B/A' ;
                
                
                
            end
            
        end
        
        % Determine effective operating conditions
        % ----------------------------------------
        
        function obj = effectiveOperatingConditions(obj,Tamb)
            
            % in this function we check whether HP can operate and whether we
            % should switch on the electric heater. We determine the produced 
            % heat from the two technologies.
            
            % Priority rule = PRIORITY IS GIVEN TO TANK CHARGING :)
            if obj.aT && obj.aSH
                obj.aSH = 0 ;
            end
            
            if obj.aT == 1 || obj.aSH == 1
                
                % if we need more heat than the maximum HP output, we switch on both HP + EH
                if obj.Qtotal > 9900
                    
                    obj.Qeh = 3000;                            % heat output of EH
                    obj.Qhp = obj.Qtotal - obj.Qeh;            % heat output of HP
                    obj = obj.HP_performance_part_load(Tamb) ;
                    
                % if we need less heat than the maximum HP output, we switch only HP
                else
                    obj.Qeh = 0;
                    obj.Qhp = obj.Qtotal;
                    obj = obj.HP_performance_part_load(Tamb);
                end
                              
                % if we are outside the heat pump operating conditions, we
                % only use the electric heater
                if (isnan(obj.COP))
                    obj.Qhp = 0;
                    obj.Qeh = 3000;
                    obj.COP = 0;
                end
                
            % if both charging-tank and space heating are OFF, switch off system
            else
                obj.Qhp = 0;
                obj.Qeh = 0;
                obj.COP = 0;
            end

            % Heat pump ON only if SH or tank charging...
            aHP = obj.aSH || obj.aT ;
                        
            % Overall balance
            obj.Qeh = aHP .* obj.Qeh ;
            obj.Qhp = aHP .* obj.Qhp ;
            obj.COP = aHP .* obj.COP ;
            obj.Qtotal = obj.Qeh + obj.Qhp;

        end
        
        % Heat-pump performance prediction methods
        % ----------------------------------------
        
        function obj = HP_performance_part_load(obj,Tamb)
            
            %%% This function is fitted from the FULL RANGE of performance data for the PUHZ-W85VHA2
            %%% in the Ecodan Databook Volume 4.1, 2019. Page A-94. It can be applied
            %%% across the full range of heat pump heating capacity (min, mid, nom and max).
            %%% This function produces up to 28% COP over-prediction at the lowest flow
            %%% temperature conditions (T_flow = 25 C and T_amb = -2 C);
            
            % Q is heating capacity in Watts
            % T_flow is heat pump flow temperature in either Kelvin or deg C
            % T_a is outdoor ambient temperature in either Kelvin or deg C
            
            % increase in loop temperature due to EH
            TincrEH = obj.Qeh/(obj.mDotPL * obj.water.cp);
            T_flow = obj.T(1)-TincrEH ;
            
            % COP is the coefficient of performance
            
            x = (T_flow-Tamb) ./ 80;       
            y = (obj.Qhp)./ 8500;

            p00 =       10.91;
            p10 =      -19.08;
            p01 =      -2.591;
            p20 =       9.306;
            p11 =       3.586;
                
            obj.COP = p00 + p10*x + p01*y + p20*x.^2 + p11*x.*y;
            
            % assumed that outside of the tabulated operatingrnage of the heat pump the
            % heating is provided by a backup booster or immmersion heater
            
            T_flow = T_flow-273.15;
            Tamb_C = Tamb-273.15;
            
            x1 = (T_flow>60);
            x2 = (T_flow>55)&(Tamb_C<2);
            x3 = (T_flow>45)&(Tamb_C<-10);
            x4 = (Tamb_C<-10)&(T_flow<35);
            x5 = (Tamb_C<-20);
            x6 = (obj.Qhp<5400)&(T_flow>55);
            x7 = (obj.Qhp<3200);
            x8 = (obj.Qhp>9900);
            
            obj.COP(x1|x2|x3|x4|x5|x6|x7|x8) = NaN;
            
        end
        
        function obj = HP_performance_nominal(obj,Tamb)
                     
            %%% This function is fitted from NOMINAL CAPACITY performance data for the PUHZ-W85VHA2
            %%% in the Ecodan Databook Volume 4.1, 2019. Page A-94. It should be
            %%% applied only to the heat pump when operating at its nominal output
            %%% capacity (i.e. typically ~8.5 kW at moderate outdoor temperatures).
            
            % T_flow is heat pump flow temperature entered in Kelvin
            % T_a is outdoor ambient temperature entered in Kelvin
            
            % Q is heating capacity outputted in Watts
            % COP is the coefficient of performance
            
            T_flow = obj.T(1) ;
            
            x = (Tamb-253.15)/40;
            y = (T_flow-298.15)/35;
            
            p00 =       1.873;
            p10 =        3.54;
            p01 =     -0.5223;
            p20 =       1.367;
            p11 =      -3.598;
            
            obj.COP = p00 + p10*x + p01*y + p20*x.^2 + p11*x.*y;
            
            p00 =        5.16;
            p10 =       9.106;
            p01 =       0.156;
            p20 =      -5.054;
            p11 =    -0.05006;
            
            obj.Qhp = (p00 + p10*x + p01*y + p20*x.^2 + p11*x.*y)*1000;

            % assumed that outside of the tabulated operating range of the heat pump the
            % heating is provided by a backup booster or immmersion heater
            
            T_flow = T_flow-273.15;
            Tamb_C = Tamb-273.15;
            
            x1 = (T_flow>60);
            x2 = (T_flow>55)&(Tamb_C<2);
            x3 = (T_flow>45)&(Tamb_C<-10);
            x4 = (Tamb_C<-10)&(T_flow<35);
            x5 = (Tamb_C<-20);
            
            obj.COP(x1|x2|x3|x4|x5) = NaN;
            obj.Qhp(x1|x2|x3|x4|x5) = NaN;
            
        end
        
        
    end
end
