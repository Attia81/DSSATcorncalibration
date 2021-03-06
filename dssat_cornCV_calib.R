#--- Installing missing packages
pkg = c("sirad", 
        "Dasst",  
        "hydroGOF",  
        "optimr", 
        "dfoptim",
        "FME",  
        "optimx",
        "tictoc")  
ipkg = pkg %in% rownames(installed.packages())
sapply(pkg[!ipkg],function(x) install.packages(x))

#--- Load function
library(sirad)
library(Dasst)
library(hydroGOF)
library(optimr)
library(dfoptim)
library(FME)
library(optimx)
library(tictoc)

#--- Set working directory
wd = "D:/Murilo/dssat_corn/DSSATcorncalibration"#"D:/ISmalia_DSSAT"

#--- Optimization function
myfunction <- function(X,Optfig){
  
  
  #-----edit the CUL&ECO files----------
  
  out_string <- paste0("!MAIZE CULTIVAR COEFFICIENTS: MZCER047 MODEL\n",
                       "!AHMED ATTIA (MAR-2019)\n",
                       "@VAR#  VRNAME.......... EXPNO   ECO#    P1    P2    P5    G2    G3 PHINT")
  
  CalibP <- c(formatC(X[1],format="f",digits=1),formatC(X[2],format="f",digits=3),formatC(X[3],format="f",digits=1),
              formatC(X[4],format="f",digits=1), formatC(X[5],format="f",digits=2),
              formatC(X[6],format="f",digits=2))
  CalibP[5] <- paste(" ",CalibP[5],sep="")
  
  cat(out_string,
      "990001 LONG SEASON          . IB0001",CalibP,file="C:/DSSAT47/Maize/MZCER047.CUL",fill=T,append = F)
  
  out_string2 <- paste0("*MAIZE ECOTYPE COEFFICIENTS: MZCER047 MODEL\n",
                        "@ECO#  ECONAME.........  TBASE  TOPT ROPT   P20  DJTI  GDDE  DSGFT  RUE   KCAN  TSEN  CDAY")
  
  
  CalibP2 <- c(formatC(X[7],format="f",digits=1),formatC(X[8],format="f",digits=1),formatC(X[9],format="f",digits=1),
               formatC(X[10],format="f",digits=1),formatC(X[11],format="f",digits=1),
               formatC(X[12],format="f",digits=1),formatC(X[13],format="f",digits=1),formatC(X[14],format="f",digits=1),
               formatC(X[15],format="f",digits=2))
  CalibP2[2] <- paste(" ",CalibP2[2],sep="")
  CalibP2[3] <- paste("",CalibP2[3],sep="")
  CalibP2[4] <- paste(" ",CalibP2[4],sep="")
  CalibP2[5] <- paste("  ",CalibP2[5],sep="")
  CalibP2[6] <- paste("  ",CalibP2[6],sep="")
  CalibP2[7] <- paste(" ",CalibP2[7],sep="")
  CalibP2[8] <- paste(" ",CalibP2[8],sep="")
  CalibP2[9] <- paste("  ",CalibP2[9],sep="")
  
  cat(out_string2,
      "IB0001 GENERIC MIDWEST1   ",CalibP2,file="C:/DSSAT47/Maize/MZCER047.ECO",fill=T,append = F)
  
  
  setwd(paste("C:/DSSAT47/Maize",sep = ""))
  
  #--- write paramters used on the screen
  message("")
  message("Running DSSAT-MaizeCERES...")
  
  #--- Call DSSAT047.exe and run X files list within DSSBatch.v47
  system("C:/DSSAT47/DSCSM047.EXE MZCER047 B DSSBatch.v47",show.output.on.console = F)
  
  
  plantgro <- read.dssat("C:/DSSAT47/Maize/PlantGro.OUT")
  
  
  SIMtotalDW60 <- 0 
  SIMtotalDW75 <- 0 
  SIMtotalDW <- 0
  SIMGY <- 0 
  
  for(i in 1:length(plantgro)){
    
    data=as.data.frame(plantgro[[i]])
    
    SIMtotalDW60[i] <- data$CWAD[data$DAP==60]
    SIMtotalDW75[i] <- data$CWAD[data$DAP==75]
    SIMGY[i] <- data$GWAD[length(data$GWAD)] # pick last day value
  }
  
  
  simtotalDW=c(SIMtotalDW60,SIMtotalDW75)
  simGY=c(SIMGY)
  
  totalDW_rmse <- rmse(simtotalDW,OBStotalDW)
  GY_rmse <- rmse(simGY,OBSGY)
  
  y <- totalDW_rmse/100+
    GY_rmse/50
  
  
  if(Optfig==1){
    
    plot(OBSGY/1000,simGY/1000,xlim=c(0,6),ylim=c(0,6))
    SimregGY <- simGY/1000
    ObsregGY <- OBSGY/1000
    reg1<- lm(SimregGY~ObsregGY)
    abline(reg1,pch=4,col=2,lwd=2, lty=2)
    abline(0:1)
    modeleval_GY <- modeval(simGY,OBSGY)
    text(1,5,label=bquote("R"^2~":" ~ .(round(modeleval_GY$R2[[1]],digits=2))),cex=0.7) 
    text(5,2,label=noquote(paste0("RMSE: ",round(modeleval_GY$RMSE[[1]],digits=2))),cex=0.7)
    
  }
  
  print(c(X,GY_rmse,y))
  
  return(y)
  
}

#--- Read observed dataset
Obs_data = read.csv(paste(wd,"/OBS_Calib-Data_.csv",sep=""))

#--- Read optimization parameters values and ranges
par <- read.csv(paste(wd,"/Corn_calibration.csv",sep=""))

#-------------------------SC10 cultivar------------------------------

#--- Observed data for SC10 cultivar
OBStotalDW <- round(Obs_data$Value[Obs_data$Vari=="totaldryweight" & Obs_data$Nit=="190" & Obs_data$DAP %in% c("60","75") & Obs_data$Trt %in% c(1:20)],digits=0)
OBSGY <- round(Obs_data$Value[Obs_data$Vari=="GrainYield" & Obs_data$Nit=="190" & Obs_data$DAP=="110" & Obs_data$Trt %in% c(1:20)],digits=0)

#--- initial set of parameters and range
par_initia <- par$initial_values
par_min <- par$Calib_range_min
par_max <- par$Calib_range_max

#--- Initial Results
ini.res = myfunction(par_initia,Optfig=1)

#--- Optimization
resSC10 =hjkb(par=par_initia,myfunction,Optfig=0,
              lower=par_min,upper=par_max,control=list(maxfeval=100000))

res=modFit(f=myfunction,p=par_initia,Optfig=1,
           lower=par_min,upper=par_max,method="Pseudo", control=list(numiter=50000))

tic("Calibration SC10")
resoptimr=optimx::optimx(par=par_initia,myfunction,Optfig=1,itnmax=100000,
                         lower=par_min,upper=par_max,method=c("Nelder-Mead","hjkb","L-BFGS-B"), 
                         control=list(maxit=100000,all.methods=F,follow.on=T))
toc()

#--- Best set of parameters from optimx() Ordered by lower rmse
resoptimr         = resoptimr[order(resoptimr$value),]

#--- calibrated Parameters for SC10
par.optmized.SC10 = t(resoptimr)[1:length(par_initia),1]

#--- Final Results with best-fit
final.res.SC10 = myfunction(par.optmized.SC10,Optfig=1)

#-------------------------TC310 cultivar------------------------------

#--- Observed data for TC310 cultivar
OBStotalDW <- round(Obs_data$Value[Obs_data$Vari=="totaldryweight" & Obs_data$Nit=="190" & Obs_data$DAP %in% c("60","75") & Obs_data$Trt %in% c(21:40)],digits=0)
OBSGY <- round(Obs_data$Value[Obs_data$Vari=="GrainYield" & Obs_data$Nit=="190" & Obs_data$DAP=="110" & Obs_data$Trt %in% c(21:40)],digits=0)

#--- initial set of parameters and range
par_initia <- par$initial_values
par_min <- par$Calib_range_min
par_max <- par$Calib_range_max

#--- Initial Results
ini.res = myfunction(par_initia,Optfig=1)

#--- Optimization
tic("Calibration TC310")
resoptimr=optimx::optimx(par=par_initia,myfunction,Optfig=1,itnmax=100000,
                         lower=par_min,upper=par_max,method=c("Nelder-Mead","hjkb","L-BFGS-B"), 
                         control=list(maxit=100000,all.methods=F,follow.on=T))
toc()

#--- Best set of parameters from optimx() Ordered by lower rmse
resoptimr         = resoptimr[order(resoptimr$value),]

#--- calibrated Parameters for TC310
par.optmized.TC310 = t(resoptimr)[1:length(par_initia),1]

#--- Final Results with best-fit
final.res.TC310 = myfunction(par.optmized.SC10,Optfig=1)
