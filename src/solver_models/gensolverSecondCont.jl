#=
    #gelsolverFirst() for first interval OPF solver for generator with dummy sero interval
    #This is the second interval Generator Optimization Model for the contingency case
=#

function gensolverSecondCont(
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaSC positive # APP tuning parameter
  gamma positive # APP tuning parameter for across the dispatch intervals
  lambda_3; lambda_4 # APP Lagrange Multiplier corresponding to the complementary slackness
  gammaSC positive # APP tuning parameter
  lambda_2SC # APP Lagrange Multiplier corresponding to the complementary slackness
  RgMax positive; RgMin negative # Generator maximum ramp up and ramp down limits
  PgMax positive; PgMin nonnegative # Generator Limits
  c2 nonnegative; c1 nonnegative; c0 nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init # Generator injection from last iteration for base case and contingencies
  Pg_N_avg # Net average power from last iteration for base case and contingencies
  Thetag_N_avg # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N # Dual variable for net power balance for base case and contingencies
  vg_N #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgNu; PgAPPSC # Previous iterates of the corresponding decision variable values
  PgPrevNu # Previous iterates of the corresponding decision variable values
  A # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  B # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
  BSC # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
  PgNext nonnegative # Generator's belief about its output in the next interval, which is taken as the last iterate value of the present interval belief  
  selectZero # Selection parameter to include or not include the last interval for PgNext constraint on ramping select 0 to not include the constraint, and 1 otherwise
)

variables
  Pg # Generator real power output
  PgPrev # Generator's belief about its output in the previous interval
  Thetag # Generator bus angle for base case and contingencies
end

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(PgPrev-PgPrevNu)+square(Pg-PgNu))+(betaSC/2)*(square(Pg-PgAPPSC))+(gammaSC)*(Pg*BSC)-lambda_2SC*Pg+(gamma)*(PgPrev*A+Pg*B)-lambda_3*PgPrev-lambda_4*Pg+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= selectZero*(PgNext-Pg) <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
​                                                                       