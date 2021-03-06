#Portfolio Algorithm 
# By Allison Emono
# AMS 518, 2018
#Markowits algorithm is essentially controlled by target returns
#allowing target returns to flunctuate and applying convexity properties
## the below is an attempt to improve returns and minimise risk simultaneously 
## The algorithm assumes two regimes (which obviously is under selling it)
## The logic stems from the fact, with these two regimes, there are times to be greedy
## and times to be conservative with the market

setwd("/Users/allisonemono/desktop/R-sessions")
##load packages 
library("MASS")
library(BatchGetSymbols)
library(ggplot2)
library(stringr)
library(dplyr)
install.packages("zoo")
install.packages("xts")
library("quantmod")
install.packages("mixtools")
library(MASS)
#library(nnet)
#library(mixtools)

#### Required Functions ###############################
ret_assets_framed <- data.frame(read.csv("518StockData.csv", header = T))
#Markowitz
Marko_weights <- function(x,targ_mu){
  library("MASS")
  p <- length(x[1,])
  ## with mean mu 
  mu <- (colMeans(x))
  ##and variance covariance 
  ret_var <- var(x)
  var_inverse <- ginv(ret_var) ##inverse of matrix
  inv_check <- t(var_inverse) %*% ret_var ##check if inverse is inverse
  
  ## More intimate parameters 
  B_temp <- t(var_inverse) %*% mu 
  b <- mu %*% B_temp
  ones <- rep(1,p)
  a<- ones%*%B_temp
  c <- ones%*% (t(var_inverse)%*%ones)
  d <- b*c - a*a
  #target returns be some value, let's use the one from the input of the function 
  target_returns <- targ_mu
  ####
  cd<- c/d
  ad <- a/d
  bd <- b/d
  muCoeff <- as.vector(cd*target_returns - ad)
  oneCoeff <- as.vector(bd - ad*target_returns)
  w <- var_inverse%*%(muCoeff * mu + oneCoeff*ones)
  w<- as.numeric(w)
  return(w)
}

Port_port_Sharpe<-function(x,mat_A){
  mu <- colMeans(x)
  ret_var <- var(x)
  #mat_A<- cbind(w_0, w_o, w, w_2,w_sim)
  num_Mat <- ret_var%*%mat_A
  mat_A_T<- t(mat_A)
  num_Mat_num<- t(mat_A)%*%num_Mat
  inv_Mat_num<- ginv(num_Mat_num)
  ##inv_Mat_num%*%num_Mat_num
  
  mu<- as.numeric(mu)
  A_t_u <- t(mat_A)%*%mu
  one_A_t<- rep(1, length(A_t_u))
  diff_vect_au1<- A_t_u - one_A_t
  
  approx_j <- inv_Mat_num%*%diff_vect_au1
  
  scale_denum <- 1/t(one_A_t)%*%approx_j
  scale_denum<- as.numeric(scale_denum)
  j <- scale_denum*approx_j
  
  one_A_t%*%j
  
  w_recur<- mat_A%*%j ### THE TRUE j and combination of porfolios to be used 
  
  return(w_recur)
  
}
####For distributions
## Magnitude file 

R_magnitude <-function(x){
  
  R_t_mag<- matrix(nrow = nrow(x), ncol = 1 )
  for (i in 1:nrow(x)) {
    r_i <- as.numeric(x[i,])
    R_t_mag[i,] <- sqrt(r_i%*%r_i)
  }
  return (R_t_mag)
}
### Portfolio returns function
Ret_port_dist <-function(x,w){
  
  R_t_mag<- matrix(nrow = nrow(x), ncol = 1 )
  for (i in 1:nrow(x)) {
    r_i <- as.numeric(x[i,])
    R_t_mag[i,] <- (r_i%*%w)
  }
  return (R_t_mag)
}

Port_Ret_Pos <- function(x,w){
  R_w_t_pos<- matrix(nrow = nrow(x), ncol = 1 )
  for (i in 1:nrow(x)) {
    r_i <- as.numeric(x[i,])
    ##R_w_t_pos[ i,] <- abs((r_i%*%w))
    R_w_t_pos[i,] <- sqrt((r_i%*%w)*(r_i%*%w))
  }
  return (R_w_t_pos) 
}

#######Portfolio adjustment formula 
pull_portfolio<-function(R_t_mag, R_w_t, w, ret_assets_framed, targ_mu){
  x<- matrix(nrow = nrow(R_t_mag))
  
  for (i in 1:length(R_t_mag)) {
    ##R_mag_i <- dlnorm(x, fit_lognorm$estimate[1], fit_lognorm$estimate[2])
    ##chi_i <- sqrt(R_w_t[i,]*R_w_t[i,])
    if(R_w_t[i,] > R_t_mag[i,])
    { x[i,] <- 1 } 
    else {x[i,] <- 0
    w <- Marko_weights(ret_assets_framed,R_t_mag[i,])}
  }
  
  sum(x)
  return(w)
}

##Direction requirments 
port_pull_x <- function(R_t_mag, R_w_t, w, ret_assets_framed){
  x<- matrix(nrow = nrow(R_t_mag))
 
  for (i in 1:length(R_t_mag)) {
    ##R_mag_i <- dlnorm(x, fit_lognorm$estimate[1], fit_lognorm$estimate[2])
    ##chi_i <- sqrt(R_w_t[i,]*R_w_t[i,])
    if(R_w_t[i,] > R_t_mag[i,])
    { x[i,] <- 1 } 
    else {
      x[i,] <- 0
    w <- Marko_weights(ret_assets_framed,R_t_mag[i,])
    }
  }
  
  y <- cbind(w,sum(x))
  return(y)
}

#######Convexity Constant function normalising 
convexingData<-function(r_mag_Log_norm,r_mag_gamma,R_t_mag){
  
  diff_proc <- R_t_mag - r_mag_gamma
  diff_sims <- r_mag_Log_norm - r_mag_gamma
  diff_denum <- (r_mag_Log_norm - r_mag_gamma)*(r_mag_Log_norm - r_mag_gamma)
  
  numera <- diff_sims*diff_proc
  sum_denum<- sum(diff_denum)
  sum_numer <- sum(numera)
  
  alpha <- sum_numer/sum_denum
  beta <- 1-alpha
  
  return(alpha*r_mag_Log_norm+ beta*r_mag_gamma)
}

convexingCoeffs<-function(r_mag_Log_norm,r_mag_gamma,R_t_mag){
  
  diff_proc <- R_t_mag - r_mag_gamma
  diff_sims <- r_mag_Log_norm - r_mag_gamma
  diff_denum <- (r_mag_Log_norm - r_mag_gamma)*(r_mag_Log_norm - r_mag_gamma)
  
  numera <- diff_sims*diff_proc
  sum_denum<- sum(diff_denum)
  sum_numer <- sum(numera)
  
  alpha <- sum_numer/sum_denum
  beta <- 1-alpha
  
  r<-cbind(alpha,beta)
  
  return(r)
}

#########Alternative convexing such that signs not restricted to greater than 0

altConvexDist<-function(r_mag_Log_norm,r_mag_gamma, R_t_mag){
  num1 <- R_t_mag*r_mag_Log_norm
  num2 <- r_mag_Log_norm*r_mag_gamma
  
  denum1<- r_mag_Log_norm*r_mag_Log_norm
  denum2<- r_mag_Log_norm*r_mag_gamma
  
  diffTop <- num1 - num2
  diffBottom <- denum1 - denum2
  
  sum_Top <- sum(diffTop)
  sum_Bott <- sum(diffBottom)
  alpha_alt <- sum_Top/sum_Bott
  alpha_alt
  beta_alt <- 1-alpha_alt
  
  return(alpha_alt*r_mag_Log_norm+ beta_alt*r_mag_gamma)
}

altConvexDistCoeff<-function(r_mag_Log_norm,r_mag_gamma, R_t_mag){
  num1 <- R_t_mag*r_mag_Log_norm
  num2 <- r_mag_Log_norm*r_mag_gamma
  
  denum1<- r_mag_Log_norm*r_mag_Log_norm
  denum2<- r_mag_Log_norm*r_mag_gamma
  
  diffTop <- num1 - num2
  diffBottom <- denum1 - denum2
  
  sum_Top <- sum(diffTop)
  sum_Bott <- sum(diffBottom)
  alpha_alt <- sum_Top/sum_Bott
  alpha_alt
  beta_alt <- 1-alpha_alt
  
  r<-cbind(alpha_alt,beta_alt )
  return(r)
}

#############################################################################################
#############################################################################################
############################################################################################################################
##############################################################
### The aim to make sure we exploiting the market for every penny's worth when there is room to do so
### First, data prep
#############################################################################################
#############################################################################################


ret_train <- ret_assets_framed[1:1762,-1] ## slip data to ensure no look ahead info 
ret_test <- ret_assets_framed[1762:nrow(ret_assets_framed),-1] ## test data 
ret_var <- var(ret_train)
mu<- colMeans(ret_train)
target_returns<- mu%*%mu
###Created one dimension form of data to dictate magnitude of gain or loss in market
R_t_mag <- R_magnitude(ret_train)
target_returns<- 
##Inital portweight
w_0 <- Marko_weights(ret_train, target_returns) ### this will not change the entire process
w_t<- Marko_weights(ret_train, ret_mag_train[1]) #this will change based on observed
w_fear <- Marko_weights(ret_train, ret_mag_train[1]) ## This will change based on what is observed in simulation studies
w_avg <- Marko_weights(ret_train, ret_mag_train[1]) ## this will be a cum avg port
w_min<- Marko_weights(ret_train, 0) ##minest risk, hence minest return
w_max <- Marko_weights(ret_train, 1)
w_mid <- (1/2)*(w_min+w_max)
w_equal <- rep(1/30, 30)

### Port Return distribution 
p_r_d <-Ret_port_dist(ret_train, w_0)


##### fit distributions
hist(ret_mag_train, breaks = 50, main = "Return Vector Squarted Magnitude each Day", col = "Black", xlab = "Return magnitude value")
hist((p_r_d), breaks = 50, main = "Portfolio return Histogramified", col = "Grey", xlab = "Portfolio intest performance")
hist(abs(p_r_d), breaks = 50)

fit_d<- fitdistr(p_r_d, densfun = "normal")
fit_norm<- fitdistr(R_w_t, densfun = "normal")
fit_gamma <- fitdistr(R_t_mag, densfun = "gamma") 
fit_lognorm <- fitdistr(R_t_mag, densfun = "lognormal") 
fit_rt_norm <- fitdistr(R_t_mag, densfun = "normal")

set.seed(7812) 
###Extract Parameters
muLog =fit_lognorm$estimate[1]
stdLog = fit_lognorm$estimate[2]

gamShape = fit_gamma$estimate[1]
gamRate = fit_gamma$estimate[2]

munorm =fit_rt_norm$estimate[1]
stdnorm = fit_rt_norm$estimate[2]

###Use parameters to simulate distribution 
r_mag_Log_norm <-rlnorm(n = length(R_t_mag), meanlog = muLog, sdlog = stdLog)
r_mag_gamma <- rgamma(n = length(R_t_mag),shape = fit_gamma$estimate[1], rate = fit_gamma$estimate[2])
r_mag_Norm <- rnorm(n = length(R_t_mag), mean = munorm, sd = stdnorm)
p_r_d_0<- rnorm(n = length(p_r_d), mean = fit_d$estimate[1], sd = fit_d$estimate[2])
hist(p_r_d, breaks = 50)
curve(dnorm(x, fit_d$estimate[1], fit_d$estimate[2]), col="red", lwd=2, add=T)
d <- density(ret_mag_train)

curve(fit_d, col="red", lwd=2, add=T)
plot(d, main="Kernel Density of R_t_mag", col = "red")

##CONVEXIFY Fitted distribution to fit training data set
diff_proc <- R_t_mag - r_mag_gamma
diff_sims <- r_mag_Log_norm - r_mag_gamma
diff_denum <- (r_mag_Log_norm - r_mag_gamma)*(r_mag_Log_norm - r_mag_gamma)

numera <- diff_sims*diff_proc
sum_denum<- sum(diff_denum)
sum_numer <- sum(numera)

alpha <- sum_numer/sum_denum
beta <- 1-alpha

######Checking for alpha with alternative formula
num1 <- R_t_mag*r_mag_Log_norm
num2 <- r_mag_Log_norm*r_mag_gamma

denum1<- r_mag_Log_norm*r_mag_Log_norm
denum2<- r_mag_Log_norm*r_mag_gamma

diffTop <- num1 - num2
diffBottom <- denum1 - denum2

sum_Top <- sum(diffTop)
sum_Bott <- sum(diffBottom)
alpha_alt <- sum_Top/sum_Bott
beta_alt <- 1-alpha_alt

###Graphical investigation ################
layout(1:1)
hist((beta*r_mag_Log_norm+  alpha*r_mag_gamma), breaks = 50, main = "Convex Mixture of Distributions", xlab = "Values", col = "Red")
hist(r_mag_gamma, breaks = 50, main = "Histogram of Gamma Distribution", xlab = "Values", col = "Green")
hist(r_mag_Log_norm, breaks = 50, main = "Histogram of Log normal", xlab = "Values")
hist(R_t_mag, breaks = 50)

hist(R_t_mag, breaks=50)
curve(dlnorm(x,  meanlog = fit_lognorm$estimate[1],sdlog= fit_lognorm$estimate[2]), col="red", add=T)

diff_conv <- abs((alpha*r_mag_Log_norm+ beta*r_mag_gamma) - R_t_mag)
diff_lognorm<- abs(r_mag_Log_norm - R_t_mag)
sum(diff_conv) < sum(diff_lognorm) ## check for which has the better fit
plot(diff_conv) 
plot(diff_lognorm)
sum(diff_conv)
sum(diff_lognorm)
hist((beta_alt*r_mag_Log_norm+ alpha_alt*r_mag_gamma), breaks = 50, main ="Alternative Convex Combination", xlab = "Values", col = "Blue")

########Get weights for others 
#chicken weights
r_pos <- Port_Ret_Pos(ret_train, w_0)
head(p_r_d)
for (i in 1:nrow(p_r_d)) {
  if (r_pos[i]<R_t_mag[i]){
    w_fear <- Marko_weights(ret_train, R_t_mag[i])
  } else{w_fear <- Marko_weights(ret_train, r_pos[i])}
}
#for fear, check when port is below current position, if so then that mag shoud be targ

###for agjustment, simulate different streams of port returns and market returns
###if port is higher than market stick with port, else adjust target

####make First Naive readjustment mechanism
###w_t is the portfolio of interest
r_now_t<- matrix(nrow = nrow(ret_test), ncol = 1)
al_now <- alpha_alt
bet_now <- beta_alt

for (i in 1:nrow(ret_test)) {
  r_now <- as.numeric(ret_test[i,])
  r_perf <- r_now%*%w_t
  r_mag_now<- t(r_now)%*%r_now
  r_mag_now<- sqrt(r_mag_now)
  r_mag_gamma_t <- rgamma(n = 1, shape = gamShape, rate = gamRate)
  r_mag_Log_norm_t<- rlnorm(n = 1, meanlog = muLog , sdlog = stdLog)
  al_beta<- convexingCoeffs(r_mag_Log_norm_t,r_mag_gamma_t,r_mag_now)
  al_now<- al_now+al_beta[1]
  bet_now<- bet_now+al_beta[2]
  convex_mix_cum<- al_beta[1]*r_mag_Log_norm_t + al_beta[2]*r_mag_gamma_t
  convex_mix_now <-al_beta[1]*r_mag_Log_norm_t + al_beta[2]*r_mag_gamma_t
  
  if(r_perf<convex_mix_now){
    w_t<-Marko_weights(ret_train, convex_mix_cum)
  } else{ w_t<- w_t}
}



muLog =fit_lognorm$estimate[1]
stdLog = fit_lognorm$estimate[2]

gamShape = fit_gamma$estimate[1]
gamRate = fit_gamma$estimate[2]

###Hidden markov set

Nk_lower <- 500
Nk_upper <- 1700
bull_mean <- 0.25
bull_var <- 0.1
bear_mean <- 0.08
bear_var <- 0.2

mean(R_t_mag)

days <- replicate(5, sample(Nk_lower:Nk_upper, 1))
market_bull_1 <- rgamma( days[1], bull_mean, bull_var )
market_bear_2 <- rgamma( days[2], bear_mean, bear_var )
market_bull_3 <- rgamma( days[3], bull_mean, bull_var )
market_bear_4 <- rgamma( days[4], bear_mean, bear_var )
market_bull_5 <- rgamma( days[5], bull_mean, bull_var )

true_regimes <- c( rep(1,days[1]), rep(2,days[2]), rep(1,days[3]), rep(2,days[4]), rep(1,days[5]))
returns <- c( market_bull_1, market_bear_2, market_bull_3, market_bear_4, market_bull_5)

#### Readjustment using Markov models Regime Shift #####
######without risk budgeting
n_train <- nrow(ret_train)
ret_curr <- ret_train
gains<- matrix(nrow =nrow(ret_test), ncol = 1 )
risk_tot <- matrix(nrow =nrow(ret_test), ncol = 1 )
for (i in 1:nrow(ret_test)) {
  r_now <- as.numeric(ret_test[i,])
  r_perf <- r_now%*%w_t
  r_mag_now<- t(r_now)%*%r_now
  r_mag_now<- sqrt(r_mag_now)
  r_mag_gamma_t <- rgamma(n = 50, shape = gamShape, rate = gamRate)
  r_mag_Log_norm_t<- rlnorm(n = 50, meanlog = muLog , sdlog = stdLog)
  
  if(i>2){
    r_conn <- as.numeric(ret_test[i-1,])
    r_conn_mag <- t(r_conn)%*%r_conn
    r_conn_mag<- sqrt(r_conn_mag)
    r_mag_Log_norm_t<- rlnorm(n = 50, meanlog = muLog , sdlog = stdLog)#using log normal distri
    r_past_fut<- (append(R_t_mag[(n_train-100):nrow(ret_train)],r_conn, after = n_train)) ##connecting past, now and future to one distribution
    r_past_fut<- as.numeric(append(r_past_fut, r_mag_Log_norm_t, after = 25)) ## past and present is connected with future (simulations) to get eternal distribution
    hmm <- depmix(r_past_fut ~ 1, family = gaussian(), nstates = 2, data=data.frame(returns=r_past_fut))
    hmmfit <- fit(hmm, verbose = FALSE)
    post_probs <- posterior(hmmfit)
   p_n <- length(post_probs$S1)
   ret_curr <- rbind(ret_train[(n_train-100):nrow(ret_train),], ret_test[i-1,])##to run markowitz on unstale data
   ##this bind keeps the data fresh with new input to ensure current information is considered
   
    if( post_probs$S1[p_n]<post_probs$S2[p_n] ){
      ex <- post_probs$S2[p_n]*r_conn_mag
      w_t<-Marko_weights(ret_curr, ex)
      r_now <- as.numeric(ret_test[i,])
      r_perf <- r_now%*%w_t
      gains[i,]<-r_perf 
      risk_nowl_t <- t(ret_var)%*%w_t
      risk_now_t<- t(w_t)%*%risk_nowl_t
      risk_tot[i]<- risk_now_t #### in attempt to find why variance of w_t is so low, lower than expected for such high level of total gains
    }else{ 
      ex <- post_probs$S1[p_n]*r_conn_mag
      w_t<-Marko_weights(ret_curr, ex)
      r_now <- as.numeric(ret_test[i,])
      r_perf <- r_now%*%w_t
      gains[i,]<-r_perf
      risk_nowl_t <- t(ret_var)%*%w_t
      risk_now_t<- t(w_t)%*%risk_nowl_t
      risk_tot[i]<- risk_now_t
    }
    
  } else{w_t <- w_t
  r_now <- as.numeric(ret_test[i,])
  r_perf <- r_now%*%w_t
  gains[i,]<-r_perf  
  risk_nowl_t <- t(ret_var)%*%w_t
  risk_now_t<- t(w_t)%*%risk_nowl_t
  risk_tot[i]<- risk_now_t
  }
  
}
mean(risk_tot) ## even this is smaller than what is expected
sum(risk_tot) ## this as well
############################################
####Using only Portfolio distribution and with risk budgeting 
################################################
####This approach yeilds the most acceptable perfomance 
w_t_alt<- Marko_weights(ret_train, 0.5)
gains_alt<- matrix(nrow =nrow(ret_test), ncol = 1 )
for (i in 1:nrow(ret_test)) {
  r_now_start <- as.numeric(ret_test[i,]) #to begin the prediction process
  
  r_perf_then<- as.numeric(Port_Ret_Pos(ret_train, w_t_alt))
  r_perf <- r_now_start%*%w_t_alt
  N_perf_then<- length(r_perf_then)
  r_connect<- append(r_perf_then, r_perf, after = (N_perf_then))
  fit_past_fut<- fitdistr(r_connect, densfun = "normal")
  r_port_sim <- rnorm(n = nrow(ret_test), mean = fit_past_fut$estimate[1], sd = fit_past_fut$estimate[2])
  w_t_alt <- Marko_weights(ret_train, abs(r_port_sim[i]))
  gains_alt[i,] <- r_perf
  
  if(i>2){
    r_now_start <- as.numeric(ret_test[i,])
    r_now <- as.numeric(ret_test[i-1,]) ## i-1 to ensure no look ahead as the ith return is the point we are trying to predict
    r_perf_then<- as.numeric(Port_Ret_Pos(ret_train, w_t_alt))
    r_perf <- as.numeric(r_now%*%w_t_alt)
    N_perf_then<- length(r_perf_then)
    r_connect<- append(r_perf_then, r_perf, after = N_perf_then) ##connet train and recent position magnitude to one distribution
    fit_past_fut<- fitdistr(r_connect, densfun = "normal") ## fit connecting distribution 
    r_port_sim <- rnorm(n = nrow(ret_test), mean = fit_past_fut$estimate[1], sd = fit_past_fut$estimate[2])
    r_past_fut<- (append(r_perf_then[(n_train-100):nrow(ret_train)],r_perf, after = n_train))
    r_past_fut<- as.numeric(append(r_past_fut, r_port_sim, after = 25))
    hmm <- depmix(r_past_fut ~ 1, family = gaussian(), nstates = 2, data=data.frame(returns=r_past_fut))
    hmmfit <- fit(hmm, verbose = FALSE)
    post_probs <- posterior(hmmfit)
    p_n <- length(post_probs$S1)
    ret_curr_alt <- rbind(ret_train[(n_train-100):nrow(ret_train),], ret_test[i-1,]) ##to run markowitz on unstale data
    ##this bind keeps the data fresh with new input to ensure current information is considered
    if(r_port_sim[i]>0.5){ ## if foreseen returns are positive, then go into likelihood
      risk_nowl <- t(ret_var)%*%w_t_alt
      risk_now<- t(w_t_alt)%*%risk_nowl
      ##Budget Risk
      if(risk_now<0.5){ #### This statment attempts to budget the risk
        r_conn_mag <- as.numeric(r_port_sim[i])
        if( post_probs$S1[p_n]<post_probs$S2[p_n] ){
          ex <- post_probs$S2[p_n]*r_conn_mag
          w_t_alt<-Marko_weights(ret_curr_alt, ex)
          r_now_start <- as.numeric(ret_test[i,])
          r_perf <- r_now_start%*%w_t_alt
          gains_alt[i,]<-r_perf 
        }else{ 
          ex <- post_probs$S1[p_n]*r_conn_mag
          w_t_alt<-Marko_weights(ret_curr_alt, post_probs$S1[p_n])
          r_now_start <- as.numeric(ret_test[i,])
          r_perf <- r_now_start%*%w_t_alt
          gains_alt[i,]<-r_perf 
        }
        
      } else {w_t_alt <- Marko_weights(ret_curr_alt, 0)
      r_now_start <- as.numeric(ret_test[i,])
      r_perf <- r_now_start%*%w_t_alt
      gains_alt[i,]<-r_perf }
    
      
    } else {w_t_alt <- Marko_weights(ret_curr_alt, 0) 
    r_now_start <- as.numeric(ret_test[i,])
    r_perf <- r_now_start%*%w_t_alt
    gains_alt[i,]<-r_perf  }
    
    r_now_start <- as.numeric(ret_test[i,])
    r_perf <- r_now_start%*%w_t_alt
    gains_alt[i,]<-r_perf 
    
  } else{w_t_alt <- Marko_weights(ret_curr_alt, 0)
  r_now_start <- as.numeric(ret_test[i,])
  r_perf <- r_now_start%*%w_t_alt
  gains_alt[i,]<-r_perf }
  
  ### For first step 
  r_now_start <- as.numeric(ret_test[i,])
  r_perf <- r_now_start%*%w_t_alt
  gains_alt[i,]<-r_perf 
  
}

######Perforamce Check
out_var <- var(ret_test)
####Out of sample Performance
layout(1:1)
####Sharpe ratio conmbination of portfolios
### Matrix of porfolios
Mat_por<-(cbind(w_0, w_max, w_mid, w_equal, w_t, w_t_alt, w_avg))
w_sharpe <-Port_port_Sharpe(ret_train,mat_A=Mat_por)

out_sample_perf<-Ret_port_dist(x = ret_test, w= w_sharpe)
mu_ret_sharpe<- t(w_sharpe)%*%mu
riskl<- t(out_var)%*%w_sharpe
risk_sharpe<-t(w_sharpe)%*%riskl
gains_sharpe<-sum(out_sample_perf)

##Equal weight portfolio
out_comp_equal<-Ret_port_dist(x = ret_test, w= w_equal)
gains_equal<-sum(out_comp_equal)
mu_ret_eq<- t(w_equal)%*%mu
riskeql<- t(out_var)%*%w_equal
risk_eq<-t(w_equal)%*%riskeql
risk_sharpe<risk_eq

#####Average vector of porfolios 
w_avg = (1/7)*(w_sharpe+w_max+w_min+ w_equal+w_0+w_mid+w_t)
out_perf_avg<- Ret_port_dist(x = ret_test, w= w_avg)
gains_avg<-sum(out_perf_avg)
mu_ret_avg<- t(w_avg)%*%mu
risk_avgl<- t(out_var)%*%w_avg
risk_avg<-t(w_avg)%*%risk_avgl

#### check adjusted port performance Adjusted weight with no risk budget
##w_t
out_var <- var(ret_test)
out_perf_t<- Ret_port_dist(x = ret_test, w= w_t)
mu_ret_t<- t(w_t)%*%mu
risk_tl<- t(out_var)%*%w_t
risk_t<-t(w_t)%*%risk_tl
gains_w_t<-sum(gains)

######For w_t_alt with risk budget and hidden markov
out_perf_t_alt<- Ret_port_dist(x = ret_test, w= w_t_alt)
mu_ret_t_alt<- w_t_alt%*%mu
risk_tl_alt<- t(out_var)%*%w_t_alt
risk_t_alt<-t(w_t_alt)%*%risk_tl_alt
tot_gains_alt <-sum(gains_alt)

results<- cbind(head = c("Portfolio", "Mean", "Variance", "Sum of Gains"),
                c("w_t", mu_ret_t, risk_t, gains_w_t), 
                c('w_avg',mu_ret_avg, risk_avg, gains_avg), 
                c('w_equal', mu_ret_eq ,risk_eq, gains_equal),
                c('w_alt_t', mu_ret_t_alt ,risk_t_alt, tot_gains_alt), 
                c('w_sharpe', mu_ret_sharpe ,risk_sharpe, gains_sharpe))
results<- as.data.frame(results)
results

