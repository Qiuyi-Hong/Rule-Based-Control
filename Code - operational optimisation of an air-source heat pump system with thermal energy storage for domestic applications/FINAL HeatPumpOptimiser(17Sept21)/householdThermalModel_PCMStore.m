% Paul Sapin and Andreas Olympios
% 4 January 2021

classdef householdThermalModel_PCMStore

    
    properties
        
        % Set of unknowns
        % ---------------
        
        X = [   50 + 273.15 ...      % 1 = Primary loop temperature (K)
                20 + 273.15...       % 2 = Heat emitters temperature (K)
                20 + 273.15...       % 3 = Internal space temperature (K) 
                15 + 273.15...       % 4 = Building envelope temperature (K)
                0 ...                % 5 = DHW PCM tank mass fraction [0 1]
                0 ...                % 6 = SH PCM tank mass fraction [0 1]
                ]  ;    
        
        % Boundary conditions
        % -------------------
        
        Tmains
        Tamb
        TrequestDHW 
        mDotDHW
        
        % PCM tanks characteritics
        % --------------------
        
        PCM_DHW
        PCM_SH
        
        % PCM tank heat transfer effectivenesss
        % -------------------------------------
        
        epsilon = 0.8 ;
        
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
        aDHW
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
        
        controlSignalDHWtank
        controlSignalSHtank
        
    end
    
    methods
        
        % Constructor method
        % ------------------
        
        function obj = householdThermalModel_PCMStore(tankVolumeDHW,tankVolumeSH,BCs)
            
            % Water thermo-physical properties (assmued constant at 20 C and 1 bar)
            obj.water.T = 20 + 273.15 ; % K
            obj.water.p = 1e5 ;         % Pa
            obj.water.cp = refpropm('C','T',obj.water.T,'P',obj.water.p / 1000,'water');
            obj.water.rho = refpropm('D','T',obj.water.T,'P',obj.water.p / 1000,'water');
            obj.water.thermCond = refpropm('L','T',obj.water.T,'P',obj.water.p / 1000,'water');
            
            % Mass flowrates
            obj.mDotPL = obj.VdotPL .* obj.water.rho ;
            obj.mDotSL = obj.VdotSL .* obj.water.rho ;
            
            % Apply boundary conditions
            obj.Tmains = BCs.Tmains ;
            obj.TrequestDHW = BCs.TrequestDHW ;
            
            % PCM properties
            obj.PCM_DHW.latentHeat = 230e3 ;    % J/kg
            obj.PCM_SH.latentHeat = 230e3 ;     % J/kg
            obj.PCM_DHW.T = 48 + 273.15 ; 
            obj.PCM_SH.T = 48 + 273.15 ;
            obj.PCM_DHW.rho = 810 ;             % kg/m3 in liquid state
            obj.PCM_SH.rho = 810 ;              % kg/m3 in liquid state
            
            % Water-equivalent energy in PCM tanks (determines PCM mass)
%             obj.PCM_DHW.mass = obj.water.rho * tankVolumeDHW * obj.water.cp *...
%                 (obj.TrequestDHW - obj.Tmains) ...
%                 / obj.PCM_DHW.latentHeat ;
%             obj.PCM_SH.mass = obj.water.rho * tankVolumeSH * obj.water.cp *...
%                 (obj.TrequestDHW - obj.Tmains) ...
%                 / obj.PCM_SH.latentHeat ;
%             obj.PCM_DHW.V = obj.PCM_DHW.mass./obj.PCM_DHW.rho ; 
%             obj.PCM_SH.V = obj.PCM_SH.mass./obj.PCM_SH.rho ;
            
            obj.PCM_DHW.V = tankVolumeDHW ;
            obj.PCM_DHW.mass = obj.PCM_DHW.rho .* obj.PCM_DHW.V ;
            obj.PCM_SH.V = tankVolumeSH ;
            obj.PCM_SH.mass = obj.PCM_SH.rho .* obj.PCM_DHW.V ;
            
            % Create thermal-conductance matrix (constant terms)
            obj.G = zeros(length(obj.X),length(obj.X)) ;
            obj.G(2,3) = obj.Gem ;
            obj.G(3,4) = obj.Gint ;
            
            % Thermal inertia (constant terms)
            obj.C = zeros(1,length(obj.X)) ;
            obj.C(1) = obj.Cloop ;
            obj.C(2) = obj.Cem ;
            obj.C(3) = obj.Cint ;
            obj.C(4) = obj.Cenv ;
            
        end
             
        % Linear model solving function
        % -----------------------------
        
        function obj = predictThermalState(obj,timeSpan,controls,demand,irradiance,BCs)
            
            % Charge space-heating tank binary (on/off)
            obj.aSH = controls.chargeSpaceHeatingTank ;
            
            % Charge DHW tank binary (on/off)
            obj.aDHW = controls.chargeDomesticHotWaterTank ;
            
            % Thermostat control (on/off)
            obj.aT = controls.thermostat ;
            
            % Total HP+EH power if charging-tank is on
            obj.Qtotal = controls.heatingPower ;
            
            % Calculating algorithm time step
            N = max([ceil(timeSpan./obj.maxTimeStepSize)+1 2]) ;
            
            % Create time vector
            time = linspace(0,timeSpan,N) ;
            dt = time(2) - time(1) ;
            
            % Extract DHW demand
            obj.mDotDHW = demand.DHWmassFlowRate ;
            
            % Apply boundary conditions
            obj.Tamb = BCs.Tamb ;
            obj.Tmains = BCs.Tmains ;
            obj.TrequestDHW = BCs.TrequestDHW ;
            
            % Irradiance data
            Qsol = irradiance.globalHorizontalSolarIrradiance ;
            
            % Determine effective (feasible) operating conditions
            obj = obj.effectiveOperatingConditions(dt) ;
            
            for n = 2:length(time)
                
                % Source terms
                Q = zeros(1,length(obj.X)) ;
                Q(3) = obj.ksInt.*Qsol + obj.Qint + obj.Gvent.*obj.Tamb ;
                Q(4) = obj.ksEnv.*Qsol + obj.Gext.*obj.Tamb ;
                Q(1) = obj.Qtotal ;
                
                % Time-dependent thermal masses
                obj.C(5) = obj.PCM_DHW.mass .* obj.PCM_DHW.latentHeat ;
                obj.C(6) = obj.PCM_SH.mass .* obj.PCM_SH.latentHeat ;
                   
                % Symmetric maxtrix build
                fullG = obj.G + obj.G' ;
                
                % A-matrix build
                A = zeros(length(obj.X),length(obj.X)) ;
                B = zeros(1,length(obj.X)) ;
                
                for i = 1:length(obj.X)
                    for j = 1:length(obj.X)
                        A(i,j) = (i==j).*( obj.C(i)./dt + sum(fullG(i,:)) ) - ...
                            (i~=j).*fullG(i,j) ;
                    end
                    B(i) = obj.C(i).*obj.X(i)./dt + Q(i) ;
                end
                clear fullG
                
                
                % Non-symmetric explicit terms
                % ============================
                
                % Door- and window-opening contribution
                % -------------------------------------
                
                A(3,3) = A(3,3) + obj.Gvent ;
                
                % External convection
                % -------------------
                
                A(4,4) = A(4,4) + obj.Gext ;
                
                % DHW-tank charging 1-5
                % -----------------
                
                % DHW-PCM equivalent conductance term - NODE 1 
                A(1,1) = A(1,1) + ...
                    obj.aDHW .* obj.epsilon .* obj.mDotPL .* obj.water.cp ;
                B(1) = B(1) + obj.aDHW .* obj.epsilon .* obj.mDotPL .* obj.water.cp .* obj.PCM_DHW.T ;
                
                % DHW-PCM equivalent conductance term - NODE 5 
                A(5,1) = A(5,1) - ...
                    obj.aDHW .* obj.epsilon .* obj.mDotPL .* obj.water.cp ;
                B(5) =  B(5) - obj.aDHW .* obj.epsilon .* obj.mDotPL .* obj.water.cp .* obj.PCM_DHW.T ;
                
                % SH-tank charging 1-6
                % ----------------
                
                % SH-PCM equivalent conductance term - NODE 1 
                A(1,1) = A(1,1) + ...
                    obj.aSH .* obj.epsilon .* obj.mDotPL .* obj.water.cp ;
                B(1) = B(1) + obj.aSH .* obj.epsilon .* obj.mDotPL .* obj.water.cp .* obj.PCM_SH.T ;
                
                % SH-PCM equivalent conductance term - NODE 6 
                A(6,1) = A(6,1) - ...
                    obj.aSH .* obj.epsilon .* obj.mDotPL .* obj.water.cp ;
                B(6) =  B(6) - obj.aSH .* obj.epsilon .* obj.mDotPL .* obj.water.cp .* obj.PCM_SH.T ;
                
                % DHW demand - NODE 5
                % ----------
                
                B(5) = B(5) - obj.mDotDHW * obj.water.cp * (obj.TrequestDHW - obj.Tmains) ;
                
                % Thermostat control  2-6
                % ------------------
                
                % SH-PCM equivalent conductance term - NODE 2 
                A(2,2) = A(2,2) + ...
                    obj.aT .* obj.epsilon .* obj.mDotSL .* obj.water.cp ;
                B(2) = B(2) +  obj.aT .* obj.epsilon .* obj.mDotSL .* obj.water.cp .* obj.PCM_SH.T ;
                
                % SH-PCM equivalent conductance term - NODE 6 
                A(6,2) = A(6,2) - ...
                    obj.aT .* obj.epsilon .* obj.mDotSL .* obj.water.cp ;
                B(6) =  B(6) - obj.aT .* obj.epsilon .* obj.mDotSL .* obj.water.cp .* obj.PCM_SH.T ;
                
                
                obj.X = B/A' ;
                
            end
            
        end
        
        % Determine effective operating conditions
        % ----------------------------------------
        
        function obj = effectiveOperatingConditions(obj,dt)
            
            % in this function we check whether HP can operate and whether we
            % should switch on the electric heater. We determine the produced 
            % heat from the two technologies.
            
            % Priority rule = PRIORITY IS GIVEN TO DHW PCM TANK CHARGING :)
            % =============================================================
            
            if obj.aDHW && obj.aSH
                obj.aSH = 0 ;
            end
            
            % Let us check whether the PCM tanks are full!
            % ============================================
            
            % Predict DHW tank charging properties
            currentEnergy = obj.PCM_DHW.mass * obj.X(5) * obj.PCM_DHW.latentHeat ;
            maxEnergy = obj.PCM_DHW.mass * obj.PCM_DHW.latentHeat ;
            requestedEnergy = obj.mDotDHW * dt * obj.water.cp * (obj.TrequestDHW - obj.Tmains) ;
            addedEnergy = obj.epsilon * obj.aDHW * obj.mDotPL * dt * obj.water.cp * (obj.X(1) - obj.PCM_DHW.T) ;
            testAvailability =  addedEnergy - requestedEnergy < maxEnergy - currentEnergy ;
            
            if ~testAvailability
                obj.aDHW = 0 ;
            end
            
            % Predict SH tank charging properties
            currentEnergy = obj.PCM_SH.mass * obj.X(6) * obj.PCM_SH.latentHeat ;
            maxEnergy = obj.PCM_SH.mass * obj.PCM_SH.latentHeat ;
            requestedEnergy = - obj.epsilon * obj.aT * obj.mDotSL * dt * obj.water.cp * (obj.X(2) - obj.PCM_SH.T) ;
            addedEnergy = obj.epsilon * obj.aSH * obj.mDotPL * dt * obj.water.cp * (obj.X(1) - obj.PCM_SH.T) ;
            testAvailability =  addedEnergy - requestedEnergy < maxEnergy - currentEnergy ;
            
            if ~testAvailability
                obj.aSH = 0 ;
            end
         
             % Let us check whether the PCM tanks are empty!
            % ============================================
            
            % Predict DHW tank charging properties
            currentEnergy = obj.PCM_DHW.mass * obj.X(5) * obj.PCM_DHW.latentHeat ;
            requestedEnergy = obj.mDotDHW * dt * obj.water.cp * (obj.TrequestDHW - obj.Tmains) ;
            addedEnergy = obj.epsilon * obj.aDHW * obj.mDotPL * dt * obj.water.cp * (obj.X(1) - obj.PCM_DHW.T) ;
            testAvailability =  requestedEnergy <  currentEnergy + addedEnergy ;
            
            if ~testAvailability
                obj.mDotDHW = 0 ;
            end
            
            % Predict SH tank charging properties
            currentEnergy = obj.PCM_SH.mass * obj.X(6) * obj.PCM_SH.latentHeat ;
            requestedEnergy = - obj.epsilon * obj.aT * obj.mDotSL * dt * obj.water.cp * (obj.X(2) - obj.PCM_SH.T) ;
            addedEnergy = obj.epsilon * obj.aSH * obj.mDotPL * dt * obj.water.cp * (obj.X(1) - obj.PCM_SH.T) ;
            testAvailability =  requestedEnergy <  currentEnergy + addedEnergy ;
            
            if ~testAvailability
                obj.aT = 0 ;
            end
            
            
            if obj.aDHW == 1 || obj.aSH == 1
                
                % if we need more heat than the maximum HP output, we switch on both HP + EH
                if obj.Qtotal > 9900
                    
                    obj.Qeh = 3000;                            % heat output of EH
                    obj.Qhp = obj.Qtotal - obj.Qeh;            % heat output of HP
                    obj = obj.HP_performance_part_load ;
                    
                % if we need less heat than the maximum HP output, we switch only HP
                else
                    obj.Qeh = 0;
                    obj.Qhp = obj.Qtotal;
                    obj = obj.HP_performance_part_load;
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
            aHP = obj.aSH || obj.aDHW ;
            
            % Overall balance
            obj.Qeh = aHP .* obj.Qeh ;
            obj.Qhp = aHP .* obj.Qhp ;
            obj.COP = aHP .* obj.COP ;
            obj.Qtotal = obj.Qeh + obj.Qhp;

        end
        
        % Heat-pump performance prediction methods
        % ----------------------------------------
        
        function obj = HP_performance_part_load(obj)

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
            T_flow = obj.X(1)-TincrEH ;
            
            % COP is the coefficient of performance
            x = (T_flow-obj.Tamb) ./ 80;       
            y = (obj.Qhp)./ 8500;

            p00 =       10.91;
            p10 =      -19.08;
            p01 =      -2.591;
            p20 =       9.306;
            p11 =       3.586;
                
            obj.COP = p00 + p10*x + p01*y + p20*x.^2 + p11*x.*y;
            
            % assumed that outside of the tabulated operating range of the heat pump the
            % heating is provided by a backup booster or immmersion heater
            
            T_flow = T_flow-273.15;
            Tamb_C = obj.Tamb-273.15;
            
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
        
        function obj = HP_performance_nominal(obj)
            
            %%% This function is fitted from NOMINAL CAPACITY performance data for the PUHZ-W85VHA2
            %%% in the Ecodan Databook Volume 4.1, 2019. Page A-94. It should be
            %%% applied only to the heat pump when operating at its nominal output
            %%% capacity (i.e. typically ~8.5 kW at moderate outdoor temperatures).
            
            % T_flow is heat pump flow temperature entered in Kelvin
            % T_a is outdoor ambient temperature entered in Kelvin
            
            % Q is heating capacity outputted in Watts
            % COP is the coefficient of performance
            
            T_flow = obj.X(1) ;
                        
            x = (obj.Tamb-253.15)/40;
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
            Tamb_C = obj.Tamb-273.15;
            
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
