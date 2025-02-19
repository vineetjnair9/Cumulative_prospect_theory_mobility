%% CPT parameters derivation
clear; clc;

% Mode-choice parameters
load('paramhat.mat')

% Declare GLOBAL variables
global walk_time wait_time transit_time exc_time pool_time
global price ASC_transit ASC_exclusive ASC_pooled

walk_time = -paramhat(1);
wait_time = -paramhat(2);
transit_time = -paramhat(3);
exc_time = -paramhat(4);
pool_time = -paramhat(5);
price = -paramhat(6);
ASC_transit = 0; % Baseline
ASC_exclusive = paramhat(7);
ASC_pooled = paramhat(8);

disp('Value of time in $/h:')
VOT_walking = (walk_time/price)*60
VOT_waiting = (wait_time/price)*60
VOT_transit = (transit_time/price)*60
VOT_exc = (exc_time/price)*60
VOT_pool = (pool_time/price)*60

%% Risk scenarios

T = load('C:\Users\vinee\OneDrive - Massachusetts Institute of Technology\MIT\AAC\Data\Panel\Full_launch_6-10_n955');
table_orig = T.Fulllaunch610n955;

% Vary if table columns change
table = convertvars(table_orig,[7:8,10:12,48:139],'double');
num_responses = size(table,1); % Total no. of survey responses

% Each row gives risk attitude parameters - alpha, beta+, beta-, lambda
cpt = zeros(50,4);
error = zeros(50,1); % Squared 2-norm of residual

panel = @(x,respondent_num) panel_obj(x,respondent_num,table,'dynamic_u0','original',paramhat);

% Settings for non linear least squares
lb = [0,0,0,0];
ub = [1,1,1,100];
x0 = [0.5,0.5,0.5,2];

options_lsq = optimoptions('lsqnonlin','FunctionTolerance',1e-10,'OptimalityTolerance',1e-10,'Display','off',...
    'FiniteDifferenceStepSize',1e-2,'DiffMinChange',0.01);
tic
for i = 1:50
    fun = @(x) panel(x,i);
    [cpt(i,:),error(i)] = lsqnonlin(fun,x0,lb,ub,options_lsq);
end
toc

% R_type = dynamic_u0, dynamic_SMoDS
% weighting = original, modified
% optimization method = 'lsq' (nonlinear least squares), 'grid' (grid search), 'newton', 'global-opt' (Global optimization toolbox)

% With normalized lambda
cpt(:,4) = cpt(:,4) * 100;

%% Scatter plots
%respondents = 1:1:size(table,1);
respondents = 1:1:50;

figure(1)
scatter(respondents,cpt(:,1))
ylabel('\alpha')
xlabel('Respondent')

figure(2)
scatter(respondents,cpt(:,2))
ylabel('\beta^+')
xlabel('Respondent')

figure(3)
scatter(respondents,cpt(:,3))
ylabel('\beta^-')
xlabel('Respondent')

figure(4)
scatter(respondents,cpt(:,4))
ylabel('\lambda')
xlabel('Respondent')

figure(5)
scatter(respondents,error)
ylabel('Norm of residual')
xlabel('Respondent')

%% Histograms
figure(1)
histogram(cpt(:,1),10);
xlabel('\alpha')
ylabel('Number of respondents');

figure(2)
histogram(cpt(:,2),10);
xlabel('\beta^+')
ylabel('Number of respondents');

figure(3)
histogram(cpt(:,3),10);
xlabel('\beta^-')
ylabel('Number of respondents');

figure(4)
histogram(cpt(:,4),49);
xlabel('\lambda')
ylabel('Number of respondents');

%% Population averages
% Mean
alpha = mean(cpt(:,1))
beta_plus = mean(cpt(:,2))
beta_minus = mean(cpt(:,3))
lambda = mean(cpt(:,4))

%% Median
alpha = median(cpt(:,1))
beta_plus = median(cpt(:,2))
beta_minus = median(cpt(:,3))
lambda = median(cpt(:,4))

%% Minimum values
alpha = min(cpt(:,1))
beta_plus = min(cpt(:,2))
beta_minus = min(cpt(:,3))
lambda = min(cpt(:,4))

%% Maximum values
alpha = max(cpt(:,1))
beta_plus = max(cpt(:,2))
beta_minus = max(cpt(:,3))
lambda = max(cpt(:,4))

%% Standard deviations
alpha = std(cpt(:,1))
beta_plus = std(cpt(:,2))
beta_minus = std(cpt(:,3))
lambda = std(cpt(:,4))

%% Standard errors

%% Objective function for each combination of parameter values under consideration
function F = panel_obj(x,respondent_num,table,R_type,weight_type,paramhat)
    
    % Normalize lambda so that all 4 parameters lie between 0 and 1
    x(4) = x(4) * 100;

    walk_time = -paramhat(1);
    wait_time = -paramhat(2);
    transit_time = -paramhat(3);
    exc_time = -paramhat(4);
    pool_time = -paramhat(5);
    price = -paramhat(6);
    ASC_transit = 0; % Baseline
    ASC_exclusive = paramhat(7);
    ASC_pooled = paramhat(8);
       
    ref = @(u1,u2,p,CE) reference(u1,u2,p,R_type,CE);
    calc_error = @(a,b,c,d,CE_sR,u1,u2,p,R) error_func(a,b,c,d,CE_sR,u1,u2,p,R,weight_type);
    
    i = respondent_num;
    transit_walk = table.transit_walk_1(i) + table.transit_walk_2(i);
    transit_cost = table.Transit_cost(i);

    SMODS_cost = 2.2 + table.Pool_cost(i)*table.Distance_corrected(i);

    p1 = table.p1(i)/100;
    p2 = table.p2(i)/100;
    p3 = table.p3(i)/100;
    p4 = table.p4(i)/100;
    p5 = table.p5(i)/100;
    p6 = table.p6(i)/100;

    if (table.Reference(i) == 'Public transit: ${q://QID56/ChoiceGroup/SelectedChoices}' && table.transit_mode(i) == 'Bus')

        % Scenario 1
        CE = walk_time * transit_walk * 1.1 + wait_time * 15 + transit_time * table.Bus_ref_1(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 2 + wait_time * 2 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 1 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p1,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f1 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p1,R);

        % Scenario 2
        CE = walk_time * transit_walk * 1.1 + wait_time * 15 + transit_time * table.Bus_ref_2(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 2 + wait_time * 2 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 1 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p2,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f2 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p2,R);
        
        % Scenario 3      
        CE = walk_time * transit_walk * 0.9 + wait_time * 1 + transit_time * table.Bus_ref_3(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 7 + wait_time * 4 + pool_time * 5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        u2 = walk_time * 5 + wait_time * 6 + pool_time * 6.5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        R = ref(u1,u2,p3,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f3 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p3,R);
        
        % Scenario 5
        CE = walk_time * transit_walk + wait_time * 8 + transit_time * table.Bus_ref_5(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 7 + wait_time * 6 + pool_time * 6 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        u2 = walk_time * 2 + wait_time * 3 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        R = ref(u1,u2,p5,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f5 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p5,R);

        F = [f1; f2; f3; f5];   

    elseif (table.Reference(i) == 'Public transit: ${q://QID56/ChoiceGroup/SelectedChoices}' && table.transit_mode(i) == 'Subway (T)')

        % Scenario 1
        CE = walk_time * transit_walk * 1.1 + wait_time * 9 + transit_time * table.Subway_ref_1(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 2 + wait_time * 2 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 1 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p1,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f1 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p1,R);
        
        % Scenario 2
        CE = walk_time * transit_walk * 1.1 + wait_time * 9 + transit_time * table.Subway_ref_2(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 2 + wait_time * 2 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 1 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p2,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f2 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p2,R);
        
        % Scenario 3      
        CE = walk_time * transit_walk * 0.9 + wait_time * 1 + transit_time * table.Subway_ref_3(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 7 + wait_time * 4 + pool_time * 5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        u2 = walk_time * 5 + wait_time * 6 + pool_time * 8 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        R = ref(u1,u2,p3,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f3 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p3,R);
        
        % Scenario 5
        CE = walk_time * transit_walk + wait_time * 4 + transit_time * table.Subway_ref_5(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 7 + wait_time * 6 + pool_time * 6 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        u2 = walk_time * 2 + wait_time * 3 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        R = ref(u1,u2,p5,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f5 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p5,R);

        F = [f1; f2; f3; f5];  

    elseif (table.Reference(i) == 'Public transit: ${q://QID56/ChoiceGroup/SelectedChoices}' && table.transit_mode(i) == 'Commuter rail')

        % Scenario 1
        CE = walk_time * transit_walk * 1.1 + wait_time * 15 + transit_time * table.Rail_ref_1(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 2 + wait_time * 4 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 3 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p1,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f1 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p1,R);
        
        % Scenario 2
        CE = walk_time * transit_walk * 1.1 + wait_time * 20 + transit_time * table.Rail_ref_2(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 2 + wait_time * 4 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 3 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p2,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f2 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p2,R);
        
        % Scenario 3      
        CE = walk_time * transit_walk * 0.9 + wait_time * 2 + transit_time * table.Rail_ref_3(i) + price * transit_cost + ASC_transit;        
        u1 = walk_time * 7 + wait_time * 4 + pool_time * 5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        u2 = walk_time * 5 + wait_time * 6 + pool_time * 6.5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        R = ref(u1,u2,p3,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f3 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p3,R);

        % Scenario 5
        CE = walk_time * transit_walk + wait_time * 10 + transit_time * table.Rail_ref_5(i) + price * transit_cost + ASC_transit;
        u1 = walk_time * 7 + wait_time * 6 + pool_time * 6 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        u2 = walk_time * 2 + wait_time * 3 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        R = ref(u1,u2,p5,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f5 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p5,R);
        
        F = [f1; f2; f3; f5];  

    elseif table.Reference(i) == 'Exclusive ridesharing'

        exc_cost = 2.2 + table.Exc_cost(i) * table.Distance_corrected(i) + 0.42 * table.Exc_driver_wait2(i);

        % Scenario 1
        % Certainty equivalent - Sure prospect with certain alternative travel options
        CE = walk_time * 0 + wait_time * 9 + exc_time * table.Distance_corrected(i) * 5 + price * table.Exc_ref_1(i) + ASC_exclusive;
        u1 = walk_time * 5 + wait_time * 2 + pool_time * 3.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 4 + wait_time * 1 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p1,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f1 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p1,R);
        
        % Scenario 2
        CE = walk_time * 0 + wait_time * 9 + exc_time * table.Exc_ref_2(i) + price * exc_cost * 1.2 + ASC_exclusive;
        u1 = walk_time * 2 + wait_time * 4 + pool_time * 4.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        u2 = walk_time * 3 + wait_time * 3 + pool_time * 3.5 * table.Distance_corrected(i) + price * SMODS_cost * 0.8 + ASC_pooled;
        R = ref(u1,u2,p2,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f2 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p2,R);
        
        % Scenario 3
        CE = walk_time * 0 + wait_time * 1 + exc_time * table.Exc_ref_3(i) + price * exc_cost * 0.8 + ASC_exclusive;
        u1 = walk_time * 7 + wait_time * 4 + pool_time * 5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        u2 = walk_time * 5 + wait_time * 6 + pool_time * 6.5 * table.Distance_corrected(i) + price * SMODS_cost * 1.2 + ASC_pooled;
        R = ref(u1,u2,p3,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f3 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p3,R);
        
        % Scenario 5
        CE = walk_time * 0 + wait_time * 5 + exc_time * table.Exc_ref_5(i) + price * exc_cost + ASC_exclusive;
        u1 = walk_time * 7 + wait_time * 6 + pool_time * 6 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        u2 = walk_time * 2 + wait_time * 3 + pool_time * 3 * table.Distance_corrected(i) + price * SMODS_cost + ASC_pooled;
        R = ref(u1,u2,p5,CE);
%         CE_sR = CE; 
        CE_sR = value_func(x(2),x(3),x(4),CE,R);
        f5 = calc_error(x(1),x(2),x(3),x(4),CE_sR,u1,u2,p5,R);
        
        F = [f1; f2; f3; f5];  
       
    end
end

%% Calculate error for nonlinear equation
function error = error_func(alpha,beta_plus,beta_minus,lambda,CE_actual,u1,u2,p,R,weight_type)
    CE_pred = subjective(alpha,beta_plus,beta_minus,lambda,u1,u2,p,R,weight_type);
    
    % No normalization 
    error = CE_pred - CE_actual;
    
%     % With normalization
%     if (CE_actual == 0)
%         error = abs(CE_pred - CE_actual);
%     else         
%         % Taking relative error w.r.t true value (CE_sR)
%         error = abs((CE_pred - CE_sR)/CE_sR);
%     end

end

%% Calculating subjective utilities
function U_sR = subjective(alpha,beta_plus,beta_minus,lambda,u1,u2,p1,R,weight_type) 

    V = @(u) value_func(beta_plus,beta_minus,lambda,u,R);
    u = [u1,u2];
    p_vals = [p1,1-p1];

    [u_low,ind_low] = min(u);
    [u_high,~] = max(u);

    p = p_vals(ind_low);

    w = weights(p,u_low,u_high,R,alpha,weight_type);
    U_sR = w(1) * V(u_low) + w(2) * V(u_high);
end
    
%% Value function
function V = value_func(beta_plus,beta_minus,lambda,u,R)
    if (u >= R)
        V = (u-R)^beta_plus;
    else
        V = -lambda*(R-u)^beta_minus;
    end
end

%% Calculating subjective weights
function w = weights(p,u1,u2,R,alpha,weight_type)
    F = @(u) bernoulli_cdf(p,u,u1,u2);
    pi = @(p) distort(p,alpha,weight_type);
    
    if (u1 < R)
        w(1) = pi(F(u1));
    else
        w(1) = 1 - pi(1-F(u1));
    end
    
    if (u2 < R) 
        w(2) = pi(F(u2)) - pi(F(u1));
    else
        w(2) = pi(1-F(u1)) - pi(1-F(u2));
    end
end

%% Bernoulli CDF (binomial distribution with only 1 trial & 2 outcomes)
function F = bernoulli_cdf(p,u,u1,u2)
    if (u < u1)
        F = 0;
    elseif (u >= u1 && u < u2)
        F = p;
    else
        F = 1;
    end
end
        
%% Probability weighting function
function pi = distort(p,alpha,weight_type)
    if strcmp(weight_type,'original')
        pi = exp(-(-log(p))^alpha);
    elseif strcmp(weight_type,'modified')
        pi = (p^alpha)/(p^alpha + (1-p)^alpha)^(1/alpha);
    end
end

%% Determining reference point
function R = reference(u1,u2,p,R_type,CE)
    if strcmp(R_type,'dynamic_u0')
        R = CE;
    elseif strcmp(R_type,'dynamic_SMoDS')
        R = p*u1 + (1-p)*u2;
    end
end