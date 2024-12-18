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
% Optimised Case 1: Heat pump with DHW cylinder
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% In Optimisation Case 1, the standard configuration of a heat pump coupled to 
% a hot-water cylinder is investigated but this time the operation is optimised.
% The heat pump and hot-water cylinder have the same size as the baseline case:
% 8.5 kWth and 200 L, respectively. The decision variables include the binary 
% decision of whether the cylinder should be charged (α_T) and the heat 
% required by the heat pump and electric heater (heatingPower). 

%The heat-pump maximum operating temperature is 60 °C and therefore the primary loop 
% temperature rarely goes to higher values. A slightly higher value is used 
% as a constraint for the optimiser (70 °C) to provide flexibility by allowing
% the use of the electric heater at those temperatures if demand is very high. 

% We have a mixed-integer non linear problem (MINLP).
% We will use genetic algorithms to identify an optimal solution.

% Decision variables:
% (1) binary - charging-tank (on/off)
% (2) continous - heat pump + electric heater delivered power (W)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Initialisations and input data
%  ==============================

% Choose  temporal resolution
TimeResInputs   = 120       ;     % temporal resolution of inputs  (seconds)
TimeResControl = 1800       ;     % temporal resolution of control  (seconds)

% Extract inputs and adjust according to chosen temporal resolution
[ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw] = ...
    readInputs(TimeResInputs) ;

% Plot inputs
% plotInputs(ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,TimeResInputs);
plotInputsPaper(ElecPriceUK,WeatherOban,ElecPriceGermany,WeatherMunich,Ddhw,TimeResInputs);

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

objectiveFunctionName = 'TotOperCost' ;


%% PERFORM OPTIMISATION
% =====================

for tankVolumeDHW = 0.2
    
    for iLocation = 1:1
        
        % Choose location
        location = Locations{iLocation} ;
        
        %% Optimisation Problem
        %  ====================
        
        if strcmp(location,'Oban')
            range = [3,5] ;
        elseif strcmp(location,'Munich')
            range = [3,4,5,6] ;
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
            
            fprintf(['\nUsing a ',num2str(tankVolumeDHW*1000),'-L DHW tank']) ;
            
            fprintf(['\nFilename to save = ',location,Period{typicalWeek},...
                objectiveFunctionName,'_',...
                num2str(tankVolumeDHW*1000),'L_DHW']) ;
            
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
            lb  = [zeros(NstepsControl,1); Qmin* ones(NstepsControl,1)];
            ub  = [ones(NstepsControl,1) ; Qmax* ones(NstepsControl,1)];
            
            % Specify binary variables (System on/off and SH/DHW supply)
            IntCon = linspace(1,NstepsControl,NstepsControl);
            
            % Initial conditions
            ICs.fillingRatio = 0.9 ;
            ICs.Thot = 50 + 273.15 ;
            ICs.Tcold = 10 + 273.15 ;
            
            % Define objective function
            fun = @(y)OptimisedCaseModel_DHW(y,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName);
            
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
            maxIter = 5 ;
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
                NONLCON = @(y) nonLinearConstraints_DHW(y,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName) ;
                
                % Perform genetic-algorithm optimisation
                [xSol,fVal,exitflag,info,final_pop] = ...
                    ga(fun,NstepsControl*2,[],[],[],[],lb,ub,NONLCON,IntCon,opts);
                
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
                    tankEnergy,coldWaterHeight,hotWaterMass,coldWaterMass,...
                    aSH,aDHW,...
                    NtimesDHWdemandNotMet,NtimesSHdemandNotMet,DHWdemandNOTmet,...
                    AverageSystemCOP,SelfConsumption,SelfSufficiency,DailyResults] = ...
                    OptimisedCaseModel_DHW(xSol,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName);
                [C,Ceq] = nonLinearConstraints_DHW(xSol,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName) ;

                % Display time-resolved results
                plotOutputs_DHW(OPEX,COP,COPsystem,...
                    Qhp,Qeh,Wgrid,Wpv,Cimp,GlobTiltIrr,Ddhw,...
                    T,Text,tankEnergy,coldWaterHeight,...
                    aSH,aDHW,TimeResInputs,nDays,DailyResults);
            
                % Record total operational cost
                totalOPEX(cpt) = TotOperCost ;
                
                pause(0.1)
                               
                % Re-define function and constraints
                fun = @(y)OptimisedCaseModel_DHW(y,Wpv,Ddhw,GlobHorIrr,Text,Cimp,Cexp,nDays,tankVolumeDHW,ICs,objectiveFunctionName);
                
                % Determine whether iterative optimisation has converged
                if cpt == 1
                    if  exitflag ~= -2
                        
                        save([location,Period{typicalWeek},...
                            objectiveFunctionName,'_',...
                            num2str(tankVolumeDHW*1000),'L_DHW']);
                        
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
                                    num2str(tankVolumeDHW*1000),'L_DHW']);
                            end
                            
                        else
                            fprintf(['\n',...
                                'Improvement:',num2str(Improvement*100),'%%\n\n']);
                            
                            save([location,Period{typicalWeek},...
                                    objectiveFunctionName,'_',...
                                    num2str(tankVolumeDHW*1000),'L_DHW']);
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
                                    num2str(tankVolumeDHW*1000),'L_DHW']);
                                            
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
            fprintf('\nNumber of times DHW demand not met per week = %.0f',NtimesDHWdemandNotMet);
            fprintf('\nNumber of times SH demand not met per week = %.0f',NtimesSHdemandNotMet);
            fprintf('\nSelf sufficiency = %.0f',SelfSufficiency*100);
            fprintf(['\n','====================================================','\n\n']) ;
            
            % Display time-resolved results
            plotOutputs_DHW(OPEX,COP,COPsystem,...
                Qhp,Qeh,Wgrid,Wpv,Cimp,GlobTiltIrr,Ddhw,...
                T,Text,tankEnergy,coldWaterHeight,...
                aSH,aDHW,TimeResInputs,nDays,DailyResults);
           
            % Save workspace
            save([location,Period{typicalWeek},...
                                    '_8.5kWHeatPump',objectiveFunctionName,'_',...
                                    num2str(tankVolumeDHW*1000),'L_DHW_FINAL.mat']);
                               
        end
        
    end
    
end


poolobj = gcp('nocreate');
delete(poolobj);

