% Andreas Olympios and Paul Sapin
% 29 October 2020

classdef PVSystemModel
    
    properties
        
        % Panel area (m^2)
        areaPanel = 1.635;                    
        
        % Number of panels
        nPanels = 8;       
        
        % Total area of PV system
        areaTotal
        
        % Nominal panel efficiency
        etaNom = 0.1743;
        
        % Temperature coefficient (1/K)
        tempCoeff = -0.0039 ; 
        
        % Inverter efficiency
        etaInverter =0.96;
        
        % normal operating cell temperature (K) 
        NOCT = 45 + 273.15;                             
        
        % Azimuth angle -> panel orientation -> west is positive (degrees)
        azimuth = -40;                         
        
        % Inclination angle -> panel tilt angle from horizontal (degrees) 
        tilt = 30;                              
        
        % Panel length
        panellength
        
        % Absorption coefficient for solar spectrum (the rest is reflected)
        absCoeff = 0.92; 
        
        % Product of absoprtion and transmittence coefficients
        absTransCoeff = 0.9;
        
        % Emissivity for panel 
        emisPanel = 0.85; 

        % Global tilt irradiance on the system (W/m2)
        GlobalTiltIrradiance
        
        % Panel temperature
        panTemp
        
        % Power per panel
        powerPanel
        
        % PV system power
        powerSystem 

    end
    
    methods 
        
        % Constructor method
        % ------------------      
        function obj = PVSystemModel
            
            % Total panel area(m^2)
            obj.areaTotal = obj.areaPanel * obj.nPanels; 
            obj.panellength = sqrt(obj.areaPanel);
        
        end
        
        % Predicting tilt irradiance on the PV panel 
        % ------------------------------------------------
        
        function obj = PredictTiltIrradiance(obj,GdirHor,GdirNorm,GdiffHor,GextNorm,Longitude,Latitude,Country,Days,Season)
            % This function calculates global tilt irradiance based on day of the year,
            % time of the day, location, daylight saving period, panel inclination and panel orientation.
            
            % All equations from: Soteris A Kalogirou. Solar Energy Engineering:
            % Processes and Systems. Second Editition. Academic Press, 201.
            % =========================================================================================
            
            % Temporal resolution of model inputs
            TimeRes = (length(Days)*24)/length(GdirHor); %hours
            
            % Global tilt irradiance (W/m2)
            GlobTiltIrr = zeros(length(GdirHor),1);
                        
            % Local clock time (uses the middle point of the hour)
            LST = repmat(0:TimeRes:24-TimeRes,1,length(Days))' + 0.5;
            
            % in the data files, daylight savings has been applied to the local clock time
            % for all spring and summer cases (regardless of actual day)
            DS = zeros(length(GdirHor),1);
            if (strcmp(Season,'hotSummer')) || (strcmp(Season,'typicalSpring')) || (strcmp(Season,'typicalSummer'))
                DS(:) = 1;
            end
            
            % ground reflectance
            rhoG = 0.2;
            
            % Equation of time (EOT) - variation from the mean time kept by a clock running at a uniform rate
            N = Days(:);                                                  % Day of the year
            N = repmat(N,24/TimeRes,1);
            N = reshape(N,numel(N),1);
            N = N + LST./24 - 1;                                          % e.g. midday of day N = 0.5
            B = (360/364).*(N-81);                                        % Day angle
            EOT = (9.87 * sind(2*B) - 7.53 * cosd(B) -1.5 * sind(B))/60;  % Equation of time(hours)
            
            % Apparent solar time (AST)  - based on the apparent angular motion of the sun across the sky
            %correction due to longitude
            if strcmp(Country,'UK')
                SL = 0;                                                   % Reference standard longitude for the UK - Greenwich
            elseif strcmp(Country,'Germany')
                SL = 15;                                                  % Reference standard longitude for Germany
            end
            LL_corr = 4 *(SL - Longitude)/ 60;                            % Longitude correction (4 mins per degree)
            
            AST = LST + EOT - LL_corr - DS(:);                            % LL_corr always subtracted because data files show westen longitudes as negative
            
            % Solar angle calculations
            % =================================
            
            % Declination angle of earth (degrees) - this changes as it rotates around the sun
            d = 23.45.*sind((360/365).*(284+N));
            
            % Hour angle
            h = 15 .* (AST - 12); %Hour angle -> 0° = noon, -180° = midnight
            
            % solar altitude angle
            al = asind(sind(Latitude).*sind(d)+cosd(Latitude).*cosd(d).*cosd(h));
            
            % solar zenith angle
            phi = acosd(sind(Latitude).*sind(d)+cosd(Latitude).*cosd(d).*cosd(h));
            
            % incidence angle
            theta = acosd( sind(Latitude).*sind(d).*cosd(obj.tilt) - cosd(Latitude).*sind(d).*sind(obj.tilt).*cosd(obj.azimuth) + ...
                cosd(Latitude).*cosd(d).*cosd(h).*cosd(obj.tilt) + sind(Latitude).*cosd(d).*cosd(h).*sind(obj.tilt).*cosd(obj.azimuth) + ...
                cosd(d).*sind(h).*sind(obj.tilt).*sind(obj.azimuth)) ;
            
            %% Global tilt irradiance (Reindl model)
            
            % Anisotropy index  ratio of the direct normal irradiance to the normal extraterrestrial radiation
            A = GdirNorm(:) ./ GextNorm(:);
            
            
            % Beam radiation tilt factor
            R = (cosd(theta) ./ cosd(phi));
            R(theta>90) =0; % exclude R values when the sun is at sunrise or sunset (< 1C), as this leads to large errors.
            R(phi>89) = 0;
            
            %global tilt irradiation
            GlobTiltIrr(:) = (GdirHor(:) + GdiffHor(:) .* A) .* R ...
                + GdiffHor(:) .* (1-A) .* ((1+cosd(obj.tilt))./2) .* (1 + sqrt(((GdirHor(:))./(GdirHor(:)...
                + GdiffHor(:)))).*((sind(obj.tilt/2)).^3)) ...
                + (GdirHor(:) + GdiffHor(:)) .* rhoG .* ((1-cosd(obj.tilt))/2);
            
            GlobTiltIrr(isnan(GlobTiltIrr))=0;
                       
            obj.GlobalTiltIrradiance = GlobTiltIrr;
            
        end
        
        function obj = PredictPower(obj,GlobTiltIrr,Text,varargin)
            % Calculate the power output from the PV system. Inputs:
            % (1) global tilt irradiation (W/m^2)
            % (2) ambient temperature (K)
            % (3) wind speed (m/s) - OPTIONAL
            
            % if we know the wind speed, we can estimate the losses due to
            % convenction and radiation and use energy balance.
            if nargin == 4
                windSpeed = varargin{1};
                
                densAir = zeros(1,length(Text));
                viscAir = zeros(1,length(Text));
                cpAir = zeros(1,length(Text));
                thermCondAir = zeros(1,length(Text));
                
                for i=1:length(Text)
                    [densAir(1,i), viscAir(1,i), cpAir(1,i), thermCondAir(1,i)] = ...
                        refpropm('DVCL','T',Text(i),'P',101.235,'AIR.PPF');
                end
                
                Pr = viscAir.*cpAir./thermCondAir; %Prandtl number
                Re = densAir.*obj.panellength.*windSpeed./viscAir; %Reynolds number
                
                % Isothermal plate, forced convection
                Nu = nan(1,length(Text));
                lam = Re<2e5;
                Nu(lam) = 0.664.*Re(lam).^0.5.*Pr(lam).^0.3333; %Laminar flow
                Nu(~lam) = 0.036.*Pr(~lam).^0.43.*(Re(~lam).^0.8 - 9400); %Turbulent flow
                h_conv = Nu.*thermCondAir./obj.panellength;
                
                % PV temperature and power using energy balance
                for k = 1:length(Text)
                    % Energy absorbed = Energy converted to electricity + Convection loss + Radiation loss
                    energyBalance = @(x) obj.absCoeff* GlobTiltIrr(k) - obj.etaNom* GlobTiltIrr(k)...
                        - h_conv(k) *(x - Text(k)) - obj.emisPanel*5.67e-8*((x)^4 - (Text(k))^4);
                    
                    opts = optimoptions('fsolve','Display','none');
                    obj.panTemp(k) = fsolve(energyBalance,20,opts);
                    
                    % calculate power
                    obj.powerPanel(k) = obj.etaNom*(1+obj.tempCoeff.*(obj.panTemp(k)-(25+273.15)))* GlobTiltIrr(k) * obj.areaPanel;
                    obj.powerSystem(k) = obj.powerPanel(k) * obj.nPanels * obj.etaInverter ;
                end
                
                obj.powerSystem(obj.powerSystem < 0) = 0;
                
            else
                % If we don't know the wind speed, let's calculate the power output from the PV system by using the method by HOBER:
                % https://www.homerenergy.com/products/pro/docs/latest/how_homer_calculates_the_pv_cell_temperature.html
                % Inputs:
                % (1) global tilt irradiation (W/m^2)
                % (2) ambient temperature (K)
                
                % PV temperature and power using HOBER equation
                for k = 1:length(Text)
                    obj.panTemp(k) = (Text(k) + ((obj.NOCT - (20+273.15)) * (GlobTiltIrr(k)/800)*...
                        (1 - (obj.etaNom * ( 1 - obj.tempCoeff * (25 + 273.15))/obj.absTransCoeff)))) /...
                        (1 + (obj.NOCT - (20+273.15)) * (GlobTiltIrr(k)/800) *...
                        (obj.tempCoeff * obj.etaNom / obj.absTransCoeff));
                    obj.powerPanel(k) = obj.etaNom *(1 + obj.tempCoeff *(obj.panTemp(k)-(25 + 273.15))) * GlobTiltIrr(k) * obj.areaPanel;
                    obj.powerSystem(k) = obj.powerPanel(k) * obj.nPanels * obj.etaInverter ;
                end
                
                obj.powerSystem(obj.powerSystem < 0) = 0;
            end
        end
    end
end
