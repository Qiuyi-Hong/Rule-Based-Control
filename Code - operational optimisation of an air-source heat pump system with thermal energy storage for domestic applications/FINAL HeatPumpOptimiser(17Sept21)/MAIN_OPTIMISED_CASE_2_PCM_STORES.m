%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Optimisation study of a heat pump with thermal storage device %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%          MERCE-ICL           %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%  Paul Sapin, Andreas Olympios, James Freeman %%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

poolobj = gcp('nocreate')   ;
delete(poolobj)             ;
fprintf('\n')               ;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Optimised Case 2: Heat pump with PCM thermal stores for SH and DHW
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Optimisation Case 2 involves the advanced configuration with the two PCM thermal
% stores: one to store thermal energy for DHW heating and one to store thermal 
% energy for SH. The aim is to explore the potential for even further economic 
% and energy-efficiency improvements using smart control in conjunction with a 
% more advanced system configuration.

% The decision variables include the binary decision of when to charge the DHW PCM 
% thermal store α_(PCM,DHW), the heat required by the heat pump and electric heater
% Q ̇_out, as well as an additional binary decision determining when to charge 
% the SH PCM thermal store α_(PCM,SH).

% The temperature for the primary loop is constrained to be lower than 60 °C.
% The reason this is slightly lower than in the previous configuration is because
% low temperatures are preferred by manufacturers for durability and lifetime 
% issues, and in this case, since this temperature is significantly higher than 
% the PCM melting point, providing additional flexibility by using a higher loop 
% temperature is not required.

% We have a mixed-integer non linear problem (MINLP).
% We will use genetic algorithms to identify an optimal solution.

% Decision variables:
% (1) binary - charging DHW PCM store (on/off)
% (2) binary - charging DHW SH store (on/off)
% (3) continous - heat pump + electric heater delivered power (W)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Initialisations and input data
%  ==============================

% Choose  temporal resolution
TimeResInputs   = 120       ;     % temporal resolution of inputs  (seconds)
TimeResControl = 1800   ;     % temporal resolution of control  (seconds)

% Extract inputs and adjust according to chosen temporal resolution
[ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw] = ...
    readInputs(TimeResInputs) ;

% Plot inputs
% plotInputs(ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,TimeResInputs);

% Locations
Locations{1} = 'Oban'       ;
Locations{2} = 'Munich'     ;

% Periods
Period{1} = 'HotSummer'     ;
Period{2} = 'ColdWinter'    ;
Period{3} = 'TypicalSpring' ;
Period{4} = 'TypicalSummer' ;
Period{5} = 'TypicalAutumn' ;
Period{6} = 'TypicalWinter' ;


%% OBJECTIVE FUNCTION
% ===================

% Choices are :
% -------------

% 'TotOperCost'                         - minimise the total OPEX
% 'AverageSystemCOP'                    - maximise the time-averaged COP
% 'SelfConsumption'                     - maximise self-consumption
% 'SelfSufficiency'                     - maximise self-sufficiency

objectiveFunctionName = 'SelfSufficiency' ;


%% PERFORM OPTIMISATION
% =====================

for tankVolumeDHW = [0.1]
    
    for tankVolumeSH = [0.1]
        
        BCs.Tmains = 10 + 273.15 ;
        BCs.TrequestDHW = 43 + 273.15 ;
        house = householdThermalModel_PCMStore(tankVolumeDHW,tankVolumeSH,BCs) ;
        
        for iLocation = 2
            
            % Choose location
            location = Locations{iLocation} ;
            
            if strcmp(location,'Oban')
                range = [3:6] ;
            elseif strcmp(location,'Munich')
                range = [3:6] ;
            end
            
            for typicalWeek = range
                
                % Choose time horizon - max 7 days
                nDays = 7 ;
                
                if nDays == 7
                    fprintf(['Operational optimisation of a ',Period{typicalWeek},...
                        ' week in ',location]) ;
                    fprintf(['\n',...
                        '=========================================================',...
                        '\n \n']) ;
                elseif nDays == 1
                    fprintf(['Operational optimisation of a single day during a '...
                        Period{typicalWeek},...
                        ' week in ',location]) ;
                    fprintf(['\n',...
                        '=========================================================================',...
                        '\n \n']) ;
                else
                    fprintf(['Operational optimisation of ',num2str(nDays),' days during a '...
                        Period{typicalWeek},...
                        ' week in ',location]) ;
                    fprintf(['\n',...
                        '=====================================================================',...
                        '\n \n']) ;
                end
                
                fprintf(['\nUsing a ',num2str(tankVolumeDHW*1000),'-L PCM tank for DHW and ',...
                    'a ',num2str(tankVolumeSH*1000),'-L PCM tank for SH.\n']) ;
                
                fprintf(['\nFilename to save = ',location,Period{typicalWeek},...
                    objectiveFunctionName,'_',...
                    num2str(tankVolumeDHW*1000),'L_DHW_PCM_',num2str(tankVolumeSH*1000),'L_SH_PCM.mat \n']) ;
                
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
                Days = Days(1:1:nDays);
                PV = PV.PredictTiltIrradiance(DirHorIrr,DirNormIrr,DiffHorIrr,ExtNormIrr,...
                    Longitude,Latitude,Country,Days,Season);
                GlobTiltIrr = PV.GlobalTiltIrradiance;
                
                % predict PV power
                PV = PV.PredictPower(GlobTiltIrr,Text);
                Wpv = PV.powerSystem;
                
                %%
                
                % Number of control timesteps
                NstepsControl = nDays*24*60*60/(TimeResControl);
                
                % Heat pump can provide heat in the range 3200 W < Qtotal < 9900 W
                Qmin = 3200 ; % W
                Qmax = 9900;  % W
                
                % Lower- and upper-bound only
                lb  = [zeros(NstepsControl,1) ; zeros(NstepsControl,1) ; Qmin* ones(NstepsControl,1)];
                ub  = [ones(NstepsControl,1) ; ones(NstepsControl,1) ; Qmax* ones(NstepsControl,1)];
                
                % Specify binary variables (System on/off and SH/DHW supply)
                IntCon = linspace(1,2*NstepsControl,2*NstepsControl);
                
                % Initial conditions
                ICs.fillingRatioPCM_DHW = 0.9 ;
                ICs.fillingRatioPCM_SH = 0.9 ;
                
                % Define objective function
                fun = @(y)OptimisedCaseModel_PCM(y,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,tankVolumeSH,ICs,objectiveFunctionName) ;
                
                % Define ga options
                opts = optimoptions('ga',...
                    'UseParallel',true,...
                    'FunctionTolerance',1e-1,...
                    'Display','iter');
                
                % LET'S GO :)
                %%%%%%%%%%%%%
                
                % Initialise timer
                tic;
                
                % Initialise loop parameters
                stopWhileLoop = 0 ;
                firstIteration = 1 ;
                %         lastIteration = 0;
                cpt = 1 ;
                maxIter = 8 ;
                objectiveFunction = zeros(1,maxIter) ;
                constraintsMet= -2 * ones(1,maxIter);
                totalOPEX = zeros(1,maxIter) ;
                
                while ~stopWhileLoop
                    
                    % Display iteration number
                    if cpt == 1 && firstIteration
                        fprintf(['\n',...
                            'ITERATION "',num2str(0),...
                            '"\n','-------------','\n\n']);
                    else
                        fprintf(['\n',...
                            'ITERATION ',num2str(cpt),...
                            '\n','-----------','\n\n']);
                    end
                    
                    % Non-linear constraints
                    NONLCON = @(y) nonLinearConstraints_PCM(y,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,tankVolumeSH,ICs,objectiveFunctionName) ;
                    
                    % Perform genetic-algorithm optimisation
                    [xSol,fVal,exitflag,info,final_pop] = ...
                        ga(fun,NstepsControl*3,[],[],[],[],lb,ub,NONLCON,IntCon,opts);
                    
                    % Compute convergence criterion and store objective function
                    if cpt == 1 && firstIteration
                        
                        % Record objective function and whether constraints are met
                        objectiveFunction(cpt) = fVal ;
                        constraintsMet(cpt) = exitflag;
                        firstIteration = 0 ;
                        
                    else
                        
                        % Increase counter
                        cpt = cpt + 1 ;
                        
                        % Record objective function and whether constraints are met
                        objectiveFunction(cpt) = fVal ;
                        constraintsMet(cpt) = exitflag;
                        
                        % Objective function improvement
                        Improvement = (objectiveFunction(cpt-1) - objectiveFunction(cpt))/(abs(objectiveFunction(cpt-1)));
                        
                    end
                    
                    % Obtain outputs from model
                    [~,house,...
                        TotOperCost,OPEX,...
                        T,Qhp,Qeh,Qtotal,Whp,Wgrid,COP,COPsystem,...
                        aThermostat,aSH,aDHW,...
                        NtimesDHWdemandNotMet,NtimesSHdemandNotMet,DHWdemandNOTmet,...
                        AverageSystemCOP,SelfConsumption,SelfSufficiency,DailyResults,X] = ...
                        OptimisedCaseModel_PCM(xSol,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,tankVolumeSH,ICs,objectiveFunctionName) ;
                    [C,Ceq] = nonLinearConstraints_PCM(xSol,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,tankVolumeSH,ICs,objectiveFunctionName) ;
                    
%                     % Display time-resolved results
                    plotOutputs_PCM(OPEX,COP,COPsystem,...
                        Qhp,Qeh,Wgrid,Wpv,Cimp,GlobTiltIrr,Ddhw,...
                        T,Text,[],[],...
                        aSH,aDHW,TimeResInputs,nDays,DailyResults,X,aThermostat);
                    
                    % Record total operational cost
                    totalOPEX(cpt) = TotOperCost ;
                    
                    pause(0.1)
         
                    % Re-define function and constraints
                    fun = @(y)OptimisedCaseModel_PCM(y,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,tankVolumeSH,ICs,objectiveFunctionName) ;
                    
                    % Determine whether iterative optimisation has converged
                    if cpt == 1
                        
                        if  exitflag ~= -2
                            
                            save([location,Period{typicalWeek},...
                                objectiveFunctionName,'_',...
                                num2str(tankVolumeDHW*1000),'L_DHW_PCM_',num2str(tankVolumeSH*1000),'L_SH_PCM.mat']);
                            
                            % Resume ga optimisation with final population
                            opts = optimoptions('ga',...
                                'UseParallel',true,...
                                'FunctionTolerance',1e-3,...
                                'Display','iter',...
                                'InitialPopulationMatrix',final_pop);
                            
                        else
                            % Re-initiate optimisation from different startin' point
                            opts = optimoptions('ga',...
                                'UseParallel',true,...
                                'FunctionTolerance',1e-1,...
                                'Display','iter');
                            
                            fprintf(['\n',...
                                'Does not take us anywhere good, let us re-initiate the population... Back to square one!','\n\n']);
                        end
                        
                    else
                        
                        if  exitflag == -2
                            
                            if constraintsMet(cpt-1) ~= -2
                                stopWhileLoop = 1;
                                
                            else
                                % Re-initiate optimisation from different startin' point
                                opts = optimoptions('ga',...
                                    'UseParallel',true,...
                                    'FunctionTolerance',1e-1,...
                                    'Display','iter');
                                
                                fprintf(['\n',...
                                    'Does not take us anywhere good, let us re-initiate the population... Back to square one!','\n\n']);
                            end
                            
                        else
                            % If improvement from last iteration is less than
                            % 3% we are happy - save and stop! :) 
                            if (Improvement < 0.03) && (constraintsMet(cpt-1) ~= -2)
                                stopWhileLoop = 1 ;
                                
                                if Improvement > 0
                                    save([location,Period{typicalWeek},...
                                        objectiveFunctionName,'_',...
                                        num2str(tankVolumeDHW*1000),'L_DHW_PCM_',num2str(tankVolumeSH*1000),'L_SH_PCM.mat']);
                                end
                                
                            else
                                
                                fprintf(['\n',...
                                    'Improvement:',num2str(Improvement*100),'%%\n\n']);
                                
                                save([location,Period{typicalWeek},...
                                    objectiveFunctionName,'_',...
                                    num2str(tankVolumeDHW*1000),'L_DHW_PCM_',num2str(tankVolumeSH*1000),'L_SH_PCM.mat']);
                                % Resume ga optimisation with final population
                                opts = optimoptions('ga',...
                                    'UseParallel',true,...
                                    'FunctionTolerance',1e-3,...
                                    'Display','iter',...
                                    'InitialPopulationMatrix',final_pop);
                            end
                            
                        end
                        
                    end
                    
                end
                
                load([location,Period{typicalWeek},...
                    objectiveFunctionName,'_',...
                    num2str(tankVolumeDHW*1000),'L_DHW_PCM_',num2str(tankVolumeSH*1000),'L_SH_PCM.mat']);
                bestObjFunction = objectiveFunction(cpt);
                
                % Record required time
                Elapsed_time = toc ;
                fprintf(['\n','Overall optimisation time = ',...
                    num2str(floor(Elapsed_time./60)),' minutes.\n\n']) ;
                
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
                fprintf('\n\nNumber of times DHW demand not met per week = %.0f',NtimesDHWdemandNotMet);
                fprintf('\nNumber of times SH demand not met per week = %.0f',NtimesSHdemandNotMet);
                fprintf('\nSelf sufficiency = %.0f',SelfSufficiency*100);
                fprintf(['\n','====================================================','\n\n']) ;
                
                % Display time-resolved results
                plotOutputs_PCM(OPEX,COP,COPsystem,...
                                Qhp,Qeh,Wgrid,Wpv,Cimp,GlobTiltIrr,Ddhw,...
                                T,Text,[],[],...
                                aSH,aDHW,TimeResInputs,nDays,DailyResults,X,aThermostat);
                
                % Save workspace
                save([location,...
                    Period{typicalWeek},...
                    objectiveFunctionName,'_',...
                    num2str(tankVolumeDHW*1000),'L_DHW_PCM_',num2str(tankVolumeSH*1000),'L_SH_PCM_FINAL.mat']);
                
        
            end
            
        end
        
    end
    
end



poolobj = gcp('nocreate');
delete(poolobj);

