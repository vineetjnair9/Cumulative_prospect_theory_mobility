%% Problem setup
% General reference case with gradient descent update (without sub-sampling ride offers)
% Adaptive learning rate (Momentum)

% Consider a single SMoDS server operating in a particular locality/region
clear; clc;

% SMoDS server samples ride offers and decisions every dt seconds 
% Each sampling action also = one negotiation iteration
dt = 1;
alpha = 0.9;
eta = 0.1;

% Total time horizon (s)
T = 100; 

% Negotiation iterations (1 iteration = 1 new/updated/revised ride offer)
t = 1:dt:T; % Times at which we sample ride offers
num_iters = length(t);

% Time series of desired acceptance probabilities
Mean = 0.5; SD = 0.1;
p_star = (Mean + SD.*randn(1,1)).*ones(1,num_iters);

% Update p_star after every delta iterations
delta = round(num_iters/1);
index = delta;
while index < num_iters
    p_star(index:end) = (0.5 + 0.1.*randn(1,1)).*ones(num_iters - index + 1,1);
    index = index + delta;
end

num_users = 50; % Total number of unique passengers using current server

% True CPT parameters - Vector of parameters for each passenger
% 0 < alpha_plus, alpha_minus, beta_plus, beta_minus < 1, 1 < lambda < 100

theta_true = zeros(5,num_users);
theta_true(1:4,:) = rand(4,num_users);
theta_true(5,:) = 1 + 99.*rand(1,num_users);

% Initializations for CPT params assumed by our model (completely random)
% theta_hat = zeros(5,num_users);
% theta_hat(1:4,:) = rand(4,num_users);
% theta_hat(5,:) = 1 + 99.*rand(1,num_users);

% Initializations for CPT params assumed by our model (adding Gaussian noise to true values)
theta_hat = zeros(5,num_users);
% SD = 0.1 for 1st 4 params
theta_hat(1:4,:) = theta_true(1:4,:) + 0.1.*randn(4,num_users);
% SD = 2 for loss aversion param
theta_hat(5,:) = theta_true(5,:) + 2.*randn(1,num_users);

% Bounds on range from which to draw parameters uniformly at random

% Objective utility of certain travel alternative 
% e.g. exclusive ridehailing or public transit
u0_lb = -10;
u0_ub = 10;

% Disutility due to price for SMoDS
b_sm_lb = -0.99;
b_sm_ub = -0.01;

% For this problem, assume both SMoDS outcomes have same price (differ only in travel times)
% In order to make price-based control easier/more tractable
% Lower and upper bounds on price for outcomes u1 and u2
gamma_lb1 = 3;
gamma_lb2 = 5;
gamma_ub1 = 15;
gamma_ub2 = 30;

% Construct trip characteristics
% Library of trips to use during iterations

num_trips = num_users; % Library size (# of trips/ride offer)

u0 = u0_lb + (u0_ub - u0_lb).*rand(1,num_trips);
b_sm = b_sm_lb + (b_sm_ub - b_sm_lb).*rand(1,num_trips);
gamma_lb = gamma_lb1 + (gamma_lb2 - gamma_lb1).*rand(1,num_trips);
gamma_ub = gamma_ub1 + (gamma_ub2 - gamma_ub1).*rand(1,num_trips);

% u1 --> u_low, u2 --> u_high
% Determine limiting values for x1 & x2 that ensure non-trivial choice scenario
x1_ub = u0 - b_sm.*gamma_lb;
x2_lb = u0 - b_sm.*gamma_ub;

% Then randomly pick values
x1 = x1_ub - abs(0.8.*x1_ub).*rand; 
x2 = x2_lb + abs(0.8.*x2_lb).*rand;

% Sanity check
u1_max = x1 + b_sm.*gamma_lb;
u2_min = x2 + b_sm.*gamma_ub;
valid = sum(u1_max <= u0 & u0 <= u2_min) == num_trips;

% Interval for initial guess
x0_lb = (gamma_lb1 + gamma_lb2)*0.5;
x0_ub = (gamma_ub1 + gamma_ub2)*0.5;

% If we use fsolve
x0 = x0_lb + (x0_ub - x0_lb).*rand.*ones(1,num_trips);

options = optimoptions('fsolve','Display','off','MaxIterations',10000,'MaxFunctionEvaluations',100*num_trips,'UseParallel',true);

% Initial SMoDS prices for each trip (random initialization)
gamma_curr = gamma_lb + (gamma_ub - gamma_lb).*rand(1,num_trips); % for current iteration/time step
gamma_prev = zeros(1,num_trips);

% Model SMoDS as Bernoulli dist with only 2 outcomes (u1,u2) ~ (p,1-p)
% If using purely random p
p = rand(1,num_trips);

% Ride offer iterations
% Case 1: Using gamma directly as the control input being varied
R_type = 'dynamic_SMoDS';
weight_type = 'original';

% Record actual p_sR values (averaged) to make convergence plot
p_sR_mean = zeros(1,num_iters);

% Norm of error (objective function)
error_norm = zeros(1,num_iters);
error_mean = zeros(1,num_iters);

p_sR_curr = zeros(1,num_trips);
p_sR_prev = zeros(1,num_trips);

% Vectors of parameters
alpha_plus_hat = theta_hat(1,:);
alpha_minus_hat = theta_hat(2,:);
beta_plus_hat = theta_hat(3,:);
beta_minus_hat = theta_hat(4,:);
lambda_hat = theta_hat(5,:);

alpha_plus_true = theta_true(1,:);
alpha_minus_true = theta_true(2,:);
beta_plus_true = theta_true(3,:);
beta_minus_true = theta_true(4,:);
lambda_true = theta_true(5,:);

p_sR1 = @(gamma,alpha_plus,alpha_minus,beta_plus,beta_minus,lambda) accept_prob(gamma,u0,x1,x2,p,b_sm,R_type,weight_type,alpha_plus,alpha_minus,beta_plus,beta_minus,lambda);

tic
for i = 1:num_iters
    
    % Desired probability of acceptance at current iteration/sampling time
    p_star_vec = p_star(i).*ones(1,num_trips);
       
    % Optimal price calculation based on assumed CPT model parameters
    % Only do this to set the initial condition for each period/interval when p* changes
    if (i == 1) || (p_star(i) ~= p_star(i-1))
        
        % Assume starting acceptance probability is somewhat close to desired value
        p_sR_curr = p_star_vec + 0.1.*randn(1,num_trips);
        
        % Numerical method: Solve f(gamma_hat) - p* = 0 
        % Compute subjective probability of acceptance
        p_sR_hat = @(gamma) p_sR1(gamma,alpha_plus_hat,alpha_minus_hat,beta_plus_hat,beta_minus_hat,lambda_hat);
        fun = @(gamma) p_sR_hat(gamma) - p_star_vec;
        
        % Initialize solver at previous optimal tariff
        if (i ~= 1)
            x0 = gamma_prev;
        end
        
        % Solve nonlinear system of equations
        gamma_prev = gamma_curr;
        [gamma_curr,fval,exitflag,output] = fsolve(fun,x0,options);
               
        % Calculate actual probabilities of acceptance of passengers using their true parameters and the above price

        % Under assumption that true passenger follows assumed CPT model (same functional form) but with different parameters
        p_sR_prev = p_sR_curr;
%         p_sR_curr = p_sR1(gamma_curr,alpha_plus_true,alpha_minus_true,beta_plus_true,beta_minus_true,lambda_true);
        p_sR_curr = p_star_vec + 0.1.*randn(1,num_trips);
        
        % p_sR values calculated via CPT above will differ for each trip/ride offer being considered
        % Get single value by averaging across all the samples (for convergence plot)
        p_sR_mean(i) = mean(p_sR_curr);
        error_norm(i) = norm(p_sR_curr - p_star_vec);
        error_mean(i) = abs(p_sR_mean(i) - p_star(i));
       
    % After initial condition, update tariff using only feedback until p_star changes
    else      
        % Gradient descent update (output feedback signal to modify input)
        % Gradient of error w.r.t tariff (non-normalized)
        grad = (p_sR_curr - p_sR_prev)./(gamma_curr - gamma_prev);

        % Set elements (trips) with gamma_currS = gamma_prevS to have zero graident (i.e. no update made)
        grad(isnan(grad)) = 0;
        % Normalized gradient
%         grad = grad./norm(grad);
        
        prev_update = gamma_prev - gamma_curr;
        update = (p_sR_curr - p_star_vec).*grad;
        % Normalize again
        update = update./norm(update);
        
        % Adaptive learning rate methods       
        % Momentum
        curr_update = alpha.*prev_update + eta.*update;
        gamma_prev = gamma_curr;
        gamma_curr = gamma_curr + curr_update;
              
        p_sR_prev = p_sR_curr;
        p_sR_curr = p_sR1(gamma_curr,alpha_plus_true,alpha_minus_true,beta_plus_true,beta_minus_true,lambda_true);
        
        % Get single value by averaging across all the samples (for convergence plot)
        p_sR_mean(i) = mean(p_sR_curr);
        error_norm(i) = norm(p_sR_curr - p_star(i));
        error_mean(i) = abs(p_sR_mean(i) - p_star(i));

    end
end
toc

% Plots
figure(1)
hold on
plot(t,p_star,'LineWidth',1.2);
plot(t,p_sR_mean,'LineWidth',1.2);
ylim([0 1]);
xlabel('Time (s)','Interpreter','latex');
ylabel('Probability of acceptance','Interpreter','latex');
legend('Desired $p^*(t)$','Actual mean $p^s_R(t)$','Interpreter','latex');

figure(2)
yyaxis left
plot(t,error_norm,'LineWidth',1.2);
xlabel('Time (s)','Interpreter','latex');
ylabel('$\|\textbf{p}^s_R - \textbf{p}^*\|_2$','Interpreter','latex');
yyaxis right
plot(t,error_mean,'LineWidth',1.2);
ylabel('Mean $|\bar{p}^s_R - \bar{p}^*|$','Interpreter','latex');
