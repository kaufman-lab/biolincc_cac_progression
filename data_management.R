require(foreign)
library(RMariaDB)
library(lme4)
library(lmerTest)
library(data.table)
library(sas7bdat)

# Here, set the directory where the data have been downloaded
setwd("redacted")

# ---------------------- #
# Read Biolincc datasets #
# ---------------------- #

list.files("./MESA_2020a/Primary/Exam3/Data/")
biolincce1 <- read.csv("./MESA_2020a/Primary/Exam1/Data/mesae1dres06192012.csv")
biolincce2 <- read.csv("./MESA_2020a/Primary/Exam2/Data/mesae2dres06222012.csv")
biolincce3 <- read.csv("./MESA_2020a/Primary/Exam3/Data/mesae3dres06222012.csv")
biolincce4 <- read.csv("./MESA_2020a/Primary/Exam4/Data/mesae4dres06222012.csv")
biolincce5 <- read.csv("./MESA_2020a/Primary/Exam5/Data/mesae5_drepos_20151101.csv")
names(biolincce5)[1] <- "MESAID"

# -------------------------------------------------------------- #
#  Scanners                                                      #
# -------------------------------------------------------------- #
# "ctsmod4" was missing from E4 dataset, so getting new dataset  #
# -------------------------------------------------------------- #
biolincscan <- read.dta("./MesaCardiacCTScannerDataRepository/Data/All Data/MESA_CTS_DRepos_20211206.dta")

# ---------------------------------------------------------- #
# Exact CT time - CT may be from later date than clinic exam #
# ---------------------------------------------------------- #
temp     <- read.dta("./MesaCTTimeDataRepository/Data/All Data/MesaCTTime_DRepos_20221107.dta")
ct_time  <- temp[,1:5] 

# Sub chest CT if cardiac CT is missing
ct_time$ttblcct5[is.na(ct_time$ttblcct5)] <- temp$ttbllcct5[is.na(ct_time$ttblcct5)]
ct_time$ttbllcct6 <- temp$ttbllcct6
ct_time$ct1       <- 0
ct_time$ttblcct4[ct_time$MESAID > 9000] <- 0
ct_time           <- ct_time[,c("MESAID","ct1","ttblcct2","ttblcct3","ttblcct4","ttblcct5","ttbllcct6")]

# Read events so we can exclude CABG/revascularization
events     <- read.csv("./MESA_2020a/Primary/Events/CVD/Data/mesaevthr2015_drepos_20200330.csv")

# Sites provided Dec 2021
# No sites for NR/Fam
# biolinccsite  <- read.csv(paste0(qroot, "/Transfer/Michael/mesa_air_next_datasharing/MESA_2020a/Primary/Site/mesa_site_drepos_20181106.csv"))
biolinccsite2 <- read.sas7bdat("./MesaSiteDataRepository/Data/All Data/MESA_Site_DRepos_20211206.sas7bdat")

# New Biolincc Datasets for New Recruits
biolincce1_new <- read.sas7bdat("./MESA_AirFamNR_Exam1DataRepository/Data/All Data/MesaAirE1_DRepos_20211017.sas7bdat")
biolincce5_new <- read.sas7bdat("./MESA_AirFamNR_Exam5DataRepository/Data/All Data/MesaAirE5_DRepos_20211017.sas7bdat")

# Rename outcome so it matches Classic dataset
names(biolincce5_new)[which(names(biolincce5_new)=="pagatm5")] <- "agatpm5c"

# Read AP dataset
biolinccap  <- read.csv("./MESA_Air_BioLINCC_Exposure_20231205.csv")

# Re-code NR/Fam recruitment exams to 1
biolinccap$exam[biolinccap$MESAID > 7000 & (biolinccap$exam == 4 | biolinccap$exam == 3)] <- 1

# QA checks
# summary(biolinccap[biolinccap$MESAID > 9000,])
# orig <- read.csv("/var/local/QUTE/eac_database/requests/dr0347/dr0347_biolincc_exposures.csv")
# temp <- cac1$[MESAID == "8810125"]

# ------------------------------------------ #
# Site and scanner are wide, convert to long #
# ------------------------------------------ #

m <- merge(biolinccsite2, biolincscan, by = "MESAID")
result <- list()
for(i in 1:5){
  # Scanner
  temp <- m[,c(1,2, i+7)]
  names(temp)[2:3] <- c("site","scanner")
  temp$scanner <- as.character(temp$scanner)
  temp$exam <- i
  
  # Scanner time
  temp2 <- ct_time[,c(1,i+1)]
  names(temp2) <- c("MESAID","ct_time")
  
  # Merge
  temp_merge <- merge(temp, temp2, by = "MESAID", all.x = TRUE)
  
  result[[i]] <- temp_merge
}
site_scan_long <- do.call(rbind.data.frame, result)
# Use observations even if the scanner model is missing
site_scan_long[is.na(site_scan_long$scanner),"scanner"] <- "miss"

# Classify scanner as missing if machine was used for < 10 scans 
site_scan_long[site_scan_long$scanner == "13: Discovery CT750 HD","scanner"] <- "miss"
site_scan_long[site_scan_long$scanner == "5: Light Speed 16","scanner"] <- "7: Light Speed Pro 16"
site_scan_long$scanner <- as.factor(site_scan_long$scanner)

# Combine Classic with NR/Fam for E1 & 5

bothnames <- names(biolincce1_new)[names(biolincce1_new) %in% names(biolincce1)]
temp1 <- biolincce1_new[,bothnames]
temp2 <- biolincce1[,bothnames]

biolincce1_new <- rbind.data.frame(temp1, temp2)

bothnames <- names(biolincce5_new)[names(biolincce5_new) %in% names(biolincce5)]
temp1 <- biolincce5_new[,bothnames]
temp2 <- biolincce5[,bothnames]

biolincce5_new <- rbind.data.frame(temp1, temp2)


# names(amanda)[!(names(amanda) %in% names(biolincce1))]

# ------------------------------- #
# Diabetes                        #
# ------------------------------- #

biolincce1_new$diabetes <- biolincce1_new$dm031c
biolincce1_new$diabetes[biolincce1_new$diabetes == 3] <- 2

# ------------------------------- #
# Adiposity : inverse height, hip #
# ------------------------------- #

biolincce1_new$ht1 <- 1/biolincce1_new$htcm1
biolincce1_new$ht2 <- 1/(biolincce1_new$htcm1^2)
biolincce1_new$hip <- 1/biolincce1_new$hipcm1 

# Re-scale
#biolincce1_new$ht1 <- biolincce1_new$ht1/sd(biolincce1_new$ht1, na.rm=TRUE)
#biolincce1_new$ht2 <- biolincce1_new$ht2/sd(biolincce1_new$ht2, na.rm=TRUE)
#biolincce1_new$hip <- biolincce1_new$hip/sd(biolincce1_new$hip, na.rm=TRUE)
#biolincce1$age_scaled <- (biolincce1$age1c - mean(biolincce1$age1c, na.rm = TRUE))/10
#biolincce1$hdl_scaled <- (biolincce1$hdl1  - mean(biolincce1$hdl1,  na.rm = TRUE))/10

biolincce1_new$obese <- biolincce1_new$bmi1c >= 30

# ------------------------------- #
# Re-categorize income            #
# ------------------------------- #

biolincce1_new$income <- biolincce1_new$income1
biolincce1_new$income[biolincce1_new$income1 ==  1]  <-   2500
biolincce1_new$income[biolincce1_new$income1 ==  2]  <-   6500
biolincce1_new$income[biolincce1_new$income1 ==  3]  <-  10000
biolincce1_new$income[biolincce1_new$income1 ==  4]  <-  14000
biolincce1_new$income[biolincce1_new$income1 ==  5]  <-  18000
biolincce1_new$income[biolincce1_new$income1 ==  6]  <-  22500
biolincce1_new$income[biolincce1_new$income1 ==  7]  <-  27500
biolincce1_new$income[biolincce1_new$income1 ==  8]  <-  32500
biolincce1_new$income[biolincce1_new$income1 ==  9]  <-  37500
biolincce1_new$income[biolincce1_new$income1 == 10]  <-  45000
biolincce1_new$income[biolincce1_new$income1 == 11]  <-  62500
biolincce1_new$income[biolincce1_new$income1 == 12]  <-  87500
biolincce1_new$income[biolincce1_new$income1 == 13]  <- 125000

biolincce2$income <- biolincce2$income2
biolincce2$income[biolincce2$income2 ==  1]  <-   2500
biolincce2$income[biolincce2$income2 ==  2]  <-   6500
biolincce2$income[biolincce2$income2 ==  3]  <-  10000
biolincce2$income[biolincce2$income2 ==  4]  <-  14000
biolincce2$income[biolincce2$income2 ==  5]  <-  18000
biolincce2$income[biolincce2$income2 ==  6]  <-  22500
biolincce2$income[biolincce2$income2 ==  7]  <-  27500
biolincce2$income[biolincce2$income2 ==  8]  <-  32500
biolincce2$income[biolincce2$income2 ==  9]  <-  37500
biolincce2$income[biolincce2$income2 == 10]  <-  45000
biolincce2$income[biolincce2$income2 == 11]  <-  62500
biolincce2$income[biolincce2$income2 == 12]  <-  87500
biolincce2$income[biolincce2$income2 == 13]  <- 125000

biolincce3$income <- biolincce3$income3
biolincce3$income[biolincce3$income3 ==  1]  <-   2500
biolincce3$income[biolincce3$income3 ==  2]  <-   6500
biolincce3$income[biolincce3$income3 ==  3]  <-  10000
biolincce3$income[biolincce3$income3 ==  4]  <-  14000
biolincce3$income[biolincce3$income3 ==  5]  <-  18000
biolincce3$income[biolincce3$income3 ==  6]  <-  22500
biolincce3$income[biolincce3$income3 ==  7]  <-  27500
biolincce3$income[biolincce3$income3 ==  8]  <-  32500
biolincce3$income[biolincce3$income3 ==  9]  <-  37500
biolincce3$income[biolincce3$income3 == 10]  <-  45000
biolincce3$income[biolincce3$income3 == 11]  <-  62500
biolincce3$income[biolincce3$income3 == 12]  <-  87500
biolincce3$income[biolincce3$income3 == 13]  <- 125000

# Can't find income variable in E4 dataset
biolincce4$income <- NA
#biolincce4$income[biolincce4$income4 ==  1]  <-   2500
#biolincce4$income[biolincce4$income4 ==  2]  <-   6500
#biolincce4$income[biolincce4$income4 ==  3]  <-  10000
#biolincce4$income[biolincce4$income4 ==  4]  <-  14000
#biolincce4$income[biolincce4$income4 ==  5]  <-  18000
#biolincce4$income[biolincce4$income4 ==  6]  <-  22500
#biolincce4$income[biolincce4$income4 ==  7]  <-  27500
#biolincce4$income[biolincce4$income4 ==  8]  <-  32500
#biolincce4$income[biolincce4$income4 ==  9]  <-  37500
#biolincce4$income[biolincce4$income4 == 10]  <-  45000
#biolincce4$income[biolincce4$income4 == 11]  <-  62500
#biolincce4$income[biolincce4$income4 == 12]  <-  87500
#biolincce4$income[biolincce4$income4 == 13]  <- 125000

biolincce5_new$income <- biolincce5_new$income5
biolincce5_new$income[biolincce5_new$income5 ==  1]  <-   2500
biolincce5_new$income[biolincce5_new$income5 ==  2]  <-   6500
biolincce5_new$income[biolincce5_new$income5 ==  3]  <-  10000
biolincce5_new$income[biolincce5_new$income5 ==  4]  <-  14000
biolincce5_new$income[biolincce5_new$income5 ==  5]  <-  18000
biolincce5_new$income[biolincce5_new$income5 ==  6]  <-  22500
biolincce5_new$income[biolincce5_new$income5 ==  7]  <-  27500
biolincce5_new$income[biolincce5_new$income5 ==  8]  <-  32500
biolincce5_new$income[biolincce5_new$income5 ==  9]  <-  37500
biolincce5_new$income[biolincce5_new$income5 == 10]  <-  45000
biolincce5_new$income[biolincce5_new$income5 == 11]  <-  62500
biolincce5_new$income[biolincce5_new$income5 == 12]  <-  87500
biolincce5_new$income[biolincce5_new$income5 == 13]  <- 125000
biolincce5_new$income[biolincce5_new$income5 == 14]  <- 125000
biolincce5_new$income[biolincce5_new$income5 == 15]  <- 125000


# ------------------------------- #
# Categorize exercise             #
# ------------------------------- #

biolincce1_new$exercm_cat <- biolincce1_new$exercm1c
biolincce1_new$exercm_cat[biolincce1_new$exercm1c <= 150 & !is.na(biolincce1_new$exercm1c)] <- 0
biolincce1_new$exercm_cat[biolincce1_new$exercm1c >= 151 & biolincce1_new$exercm1c <= 840 & !is.na(biolincce1_new$exercm1c)]  <- 1
biolincce1_new$exercm_cat[biolincce1_new$exercm1c >= 841 & biolincce1_new$exercm1c <= 2066 & !is.na(biolincce1_new$exercm1c)] <- 2
biolincce1_new$exercm_cat[biolincce1_new$exercm1c > 2066 & !is.na(biolincce1_new$exercm1c)] <- 3

# -------------------------------- #
# Categorize smoking and alcohol   #
# Baseline only in this section    #
# -------------------------------- #
# Any smoking 0 = never            #
#             1 = former           #
#             3 = current          #
# -------------------------------- #
# Combined smoke/second-hand smoke #
# Any smoking 0 = never/no         #
#             1 = former/no        #
#             3 = current          #
#             4 = never/yes        #
#             5 = former/yes       #
# -------------------------------- #

biolincce1_new$smkstat1      <- pmax(biolincce1_new$cig1c,biolincce1_new$cgr1c,biolincce1_new$pip1c,
                                     rep(0,length(biolincce1_new$cig1c)), na.rm=TRUE)
# Recode current smokers to be consistent with later exams
biolincce1_new$smkstat1[biolincce1_new$smkstat1 == 2] <- 3 
biolincce1_new$new_shndsmk1  <- (biolincce1_new$shndsmk1 > 0) | (biolincce1_new$smkstat1 == 3)
biolincce1_new$alcohol       <- pmax(biolincce1_new$curalc1,biolincce1_new$alcohol1,na.rm=TRUE)
biolincce1_new$comb_smk1     <- biolincce1_new$smkstat1
biolincce1_new$comb_smk1[biolincce1_new$new_shndsmk1 == TRUE & biolincce1_new$smkstat1 == 0] <- 4
biolincce1_new$comb_smk1[biolincce1_new$new_shndsmk1 == TRUE & biolincce1_new$smkstat1 == 1] <- 5

# ------------------------------------------- #
# Categorize employment outside home          #
# ------------------------------------------- #

biolincce1_new$employ <- (biolincce1_new$curjob1 %in% c(2,3,9,10))

# ------------------------------- #
# Categorize education            #
# ------------------------------- #

biolincce1_new$education                            <- biolincce1_new$educ1
biolincce1_new$education[biolincce1_new$educ1 <= 2] <- 1
biolincce1_new$education[biolincce1_new$educ1 == 3] <- 2
biolincce1_new$education[biolincce1_new$educ1 >= 4 & biolincce1_new$educ1 <= 6] <- 3
biolincce1_new$education[biolincce1_new$educ1 >= 7] <- 4

# ------------------------------- #
# Cholesterol                     #
# hghchol1, chol1, hdl1, trig1    #
# Names ok                        #
# ------------------------------- #
summary(biolincce1_new[,c("hghchol1","chol1","hdl1","trig1")])

# ------------------------------------ #
# Exam #'s and fu_time = 0 at baseline #
# ------------------------------------ #

biolincce1_new$fu_yr   <- 0
biolincce1_new$exam    <- 1
biolincce2$exam        <- 2
biolincce3$exam        <- 3
biolincce4$exam        <- 4
biolincce5_new$exam    <- 5

# ------------------------------------ #
# Reshape long to wide                 #
# ------------------------------------ #

tempb <- biolincce1_new[,c("MESAID","ht1","ht2","hip","education","employ","smkstat1","new_shndsmk1","comb_smk1","diabetes","hghchol1",
                           "waistcm1","wtlb1","age1c","pkyrs1c","trig1","hdl1","chol1", "gender1","race1c","exercm_cat","cig1c","sttn1c")]
temp1 <- unname(biolincce1_new[,c("MESAID","agatpm1c","cig1c", "fu_yr",  "sttn1c","exam","smkstat1","shndsmk1","income")])
temp2 <- unname(biolincce2[    ,c("mesaid","agatpm2c","cig2c", "E12DyC", "sttn2c","exam","smkstat2","shndsmk2","income")]) # ct time missing
temp3 <- unname(biolincce3[    ,c("mesaid","agatpm3c","cig3c", "e13dyc", "sttn3c","exam","smkstat3","shndsmk3","income")]) # ct time missing
temp4 <- unname(biolincce4[    ,c("mesaid","agatpm4c","cig4c", "e14dyc", "sttn4c","exam","smkstat4","shndsmk4","income")]) # "ctsmod4" missing, ct time missing
temp5 <- unname(biolincce5_new[,c("MESAID","agatpm5c", "cig5c","e15ctdyc", "sttn5c","exam","smkstat5","shndsmk5","income")]) 
names(temp1) <- c("MESAID","agatpc","cigc","fu_yr","statin","exam","smkstat","shndsmk","income")
names(temp2) <- c("MESAID","agatpc","cigc","fu_yr","statin","exam","smkstat","shndsmk","income")
names(temp3) <- c("MESAID","agatpc","cigc","fu_yr","statin","exam","smkstat","shndsmk","income")
names(temp4) <- c("MESAID","agatpc","cigc","fu_yr","statin","exam","smkstat","shndsmk","income")
names(temp5) <- c("MESAID","agatpc","cigc","fu_yr","statin","exam","smkstat","shndsmk","income")

biolincc_long <- merge(merge(merge(tempb, rbind.data.frame(temp1, temp2, temp3, temp4, temp5), by = "MESAID", all = TRUE), biolinccap, 
                             by = c("MESAID","exam"), all = TRUE), site_scan_long, by=c("MESAID","exam"), all.x = TRUE)

summary(biolincc_long[!is.na(biolincc_long$agatpc) & !is.na(biolincc_long$pm25_bl),])

# --------------------------------- #
# Center and scale covariates by SD #
# --------------------------------- #

biolincc_long[,c("ht1","ht2","hip","waistcm1","wtlb1","trig1","hdl1","chol1")] <- 
  scale(biolincc_long[,c("ht1","ht2","hip","waistcm1","wtlb1","trig1","hdl1","chol1")])

# ------------------------------------------ #
# Center income and scale covariates by 1000 #
# ------------------------------------------ #

biolincc_long$income   <- (biolincc_long$income - mean(biolincc_long$income, na.rm = TRUE))/1000

# -------------------------------- #
# Scale exposure                   #
# -------------------------------- #
# increments are 5µg/m3 for PM2.5  #
# 40 ppb for NOx                   #
# 10 ppb for NO2                   #
# -------------------------------- #

biolincc_long$pm25_bl_scaled <- biolincc_long$pm25_bl/5
biolincc_long$pm25_fu_scaled <- biolincc_long$pm25_fu/5

biolincc_long$nox_bl_scaled <- biolincc_long$nox_bl/40
biolincc_long$nox_fu_scaled <- biolincc_long$nox_fu/40

biolincc_long$no2_bl_scaled <- biolincc_long$no2_bl/10
biolincc_long$no2_fu_scaled <- biolincc_long$no2_fu/10

# QA check
table(biolincc_long[!is.na(biolincc_long$agatpc),c("scanner","exam")])

# ----------------------------------------------------------------------------------------------------------------- #
# Smoking
# ----------------------------------------------------------------------------------------------------------------- #
# Recode exams 2-5 smoking to match baseline coding
# ----------------------------------------------------------------------------------------------------------------- #
# Combined smoke/second-hand smoke 
# Any smoking 0 = never/no         
#             1 = former/no        
#             3 = current (all current smokers are exposed to their own SHS)          
#             4 = never/yes        
#             5 = former/yes       
# ----------------------------------------------------------------------------------------------------------------- #

# Second hand smoke is true if they reported any second hand smoke or 
# if there was evidence they were a current smoker at the time
  biolincc_long$new_shndsmk <- (biolincc_long$shndsmk > 1) | (biolincc_long$smkstat == 3) | (biolincc_long$cigc == 2)

# Impute missing secondhand smoke by selecting another of their records where smoking status is not missing
  for (i in unique(biolincc_long$MESAID[is.nan(biolincc_long$shndsmk)])){
    biolincc_long$new_shndsmk[biolincc_long$MESAID == i & is.nan(biolincc_long$new_shndsmk)] <- 
      sample(biolincc_long$new_shndsmk[biolincc_long$MESAID == i & !is.na(biolincc_long$new_shndsmk)], 1)
  }

  biolincc_long$new_shndsmk[is.na(biolincc_long$new_shndsmk)] <- -999
  biolincc_long$comb_smk    <- biolincc_long$smkstat
  
# "Don't know" was coded as 4 at Exam 5 and 9 otherwise; impute instead
  biolincc_long$comb_smk[biolincc_long$comb_smk == 4]  <- -999
  biolincc_long$comb_smk[biolincc_long$comb_smk == 9]  <- -999

# "Former quit less than a year ago" recoded to "former"
  biolincc_long$comb_smk[biolincc_long$comb_smk == 2]  <- 1

# Recode cig smoking to match smkstat
  biolincc_long$cigc[biolincc_long$cigc == 2]  <- 3
  biolincc_long$comb_smk <- pmax(biolincc_long$cigc, biolincc_long$comb_smk, na.rm = TRUE)

# Make sure smkstat 
  biolincc_long$comb_smk[biolincc_long$new_shndsmk == 1 & biolincc_long$smkstat == 0] <- 4
  biolincc_long$comb_smk[biolincc_long$new_shndsmk == 1 & biolincc_long$smkstat == 1] <- 5

# Impute smoking status if missing
for (j in 2:5){
  upts   <- biolincc_long[biolincc_long$exam == 1, c("MESAID","comb_smk")]
  newpts <- biolincc_long[biolincc_long$exam == j, c("MESAID","comb_smk")]
  m <- merge(upts, newpts, by = "MESAID", all.x = TRUE)
  m$comb_smk.x[!is.na(m$comb_smk.y)] <- m$comb_smk.y[!is.na(m$comb_smk.y)]
  biolincc_long$comb_smk[biolincc_long$exam == j] <- m$comb_smk.x[match(biolincc_long$MESAID[biolincc_long$exam == j], m$MESAID)] 
}

# QA Check
table(biolincc_long[,c("comb_smk","exam")], useNA = "always")
table(biolincc_long[,c("comb_smk","cigc")], useNA = "always")
table(biolincc_long[,c("cigc","exam")], useNA = "always")

# ----------------------------------------------------- #
# Add indicators for sub-cohort
# ----------------------------------------------------- #
biolincc_long$cohort <- "CLASSIC"
biolincc_long$cohort[biolincc_long$MESAID > 7000] <- "FAM"
biolincc_long$cohort[biolincc_long$MESAID > 9000] <- "NR"

# ----------------------------------------------------- #
# If statin is missing but sttn1c = 1 then statin is 1
# ----------------------------------------------------- #
for (j in 2:5){
  upts <- unique(biolincc_long$MESAID[biolincc_long$statin == 1 & biolincc_long$exam < j])
  biolincc_long$statin[biolincc_long$MESAID %in% upts & biolincc_long$exam == j] <- 1
  if (j < 5){
    upts <- biolincc_long$MESAID[is.na(biolincc_long$statin) & biolincc_long$exam == j & !is.na(biolincc_long$agatpc)]
    pre  <- biolincc_long[biolincc_long$exam == (j-1) & biolincc_long$MESAID %in% upts,c("MESAID","statin")]
    post <- biolincc_long[biolincc_long$exam == (j+1) & biolincc_long$MESAID %in% upts,c("MESAID","statin")]
    m <- merge(pre, post, by = "MESAID")
    same.pts <- m$MESAID[!is.na(m$statin.x) & !is.na(m$statin.y) & m$statin.x == m$statin.y]
      for (k in same.pts){
        biolincc_long$statin[biolincc_long$MESAID == k & biolincc_long$exam == j] <- biolincc_long$statin[biolincc_long$MESAID == k & biolincc_long$exam == (j-1)]
      }
  }
}

table(biolincc_long$exam, !is.na(biolincc_long$income), useNA = "always")

# ----------------------------------------------------- #
# Calculate permanent income
# ----------------------------------------------------- #
setDT(biolincc_long)
permanent_income <- biolincc_long[,list(income = mean(income, na.rm=TRUE)),by="MESAID"]
biolincc_long <- merge(biolincc_long[,-"income"], permanent_income, by = "MESAID", all.x = TRUE)

# ----------------------------------------------------- #
# Exclude revasc and CBG
# ----------------------------------------------------- #
biolincc_long <- merge(biolincc_long, events[,c("MESAID","CBG","CBGTT","REVC","REVCTT")], by = "MESAID", all.x = TRUE)

# ----------------------------------------------------- #
# Export file for use later
# ----------------------------------------------------- #
#write.csv(biolincc_long,"biolincc_long.csv")

