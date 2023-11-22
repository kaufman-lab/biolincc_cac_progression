# Code: Association between CAC Progression and Air Pollution

This repository contains code that shows the analysis method that was used to characterize the association between CAC progression and air pollution in MESA Air (originally published in the Lancet: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5019949/).  Briefly, MESA Air used cardiac CT scan data from participants from six clinic centers that were scanned 2 - 4 times over a 10 - 12 year period from 2000 to 2012.  Air pollution concentrations were determined using a spatio-temporal modeling method that incorporates regulatory and study-specific pollution monitoring data with hundreds of associated geographic variables.  This modeling method produces location-specific values and allowed researchers to assign temporally-relevant exposures to participants according to their specific address histories from 1999 onward.  A full description of the MESA Air study can be found in the American Journal of Epidemiology: https://doi.org/10.1093/aje/kws169. The code in this repository, combined with the publicly available datasets described below, can be used to conduct the analysis described in the Lancet paper.  

# MESA Air Pollution Data available in BIOLINCC

Data sharing is an important component of our research, and we have released de-identified datasets as part of the NIH/NHLBI BioLINCC repository.  Together with the MESA Coordinating Center, we have generated (and de-identified) datasets with appropriately averaged air pollution predictions, that will allow for site adjustment, and contain the updated, well-documented neighborhood SES indices for all participants including the MESA Air New Recruits. The predictions that are included in this dataset are based on updated models that generate predictions through 2017. We also plan to provide BioLINCC with the most-used exposure periods (for example, the year prior to each clinic exam). These will cover a wide variety of possible future studies as well as the ability to conduct the majority of analyses conducted by MESA Air Next investigators. 

BioLINCC datasets for MESA can be requested at https://biolincc.nhlbi.nih.gov/studies/mesa/

We recommend that you read the BioLINCC FAQ carefully, as it describes what is required to request the datasets this code uses.  While BioLINCC data is publicly available, the data is still subject to the NIH IRB-reviewed protocol that requires researchers using the data to be themselved under the oversight of an IRB.

https://biolincc.nhlbi.nih.gov/faq/

# Differences between Lancet Paper and Re-Analyzed Results

Using updated air pollution provided in the Biolincc datasets produces somewhat different results from the original analysis, although the new results are within the original CI's and still statistically significant.  The Lancet abstract reported an increase of 4.1 Agatston units per year per 5 µg/m3 for PM2.5 and 4.8 units per year per 40 ppb.   Using the datasets provided by BioLINCC, my new result is 2.9 Agatston units per year per 5 µg/m3 for PM2.5 and 6.8 units per year per 40 ppb NOx.  These differences can be explained as detailed below.

Updated PM2.5 and NOx: When providing data to Biolincc, we decided to use the most up-to-date model predictions calculated using models extended through Exam 6 (https://pubmed.ncbi.nlm.nih.gov/34086258/) rather than the original model predictions (https://pubmed.ncbi.nlm.nih.gov/25398188/).  This change impacts the PM2.5 result by about 2 Agatston units/year and NOx by 0.4 units per year.

Biolincc dataset: There are some small differences in the number of participants/observations between the original dataset and the data I was provided for biolincc due to changes made by the MESA Coordinating Center in the final datasets.  Specifically, there are a few more scans available in the newer dataset, and there were some changes in revascularizations or revascularization times.  The upshot of this is that the results are somewhat sensitive to which participants are included, and attenuates the PM2.5 results by about 0.3 units/year and the NOx result by about 0.1 units/year.

Neighborhood socioeconomic status (SES): The SES variables that we were allowed to include in the Biolincc dataset (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5098701/) are somewhat different from what we were provided at the time of the original analysis.  This change attenuates the NOx result by about 1.3 units/year and the PM2.5 result by about 0.1 units/year.

Scanner: When I reviewed the datasets for this analysis I realized that the same scanner model sometimes had slightly different scanner coding at different exams (for example "Imatron C-150" vs "3: IMATRON C-150").  Since I originally didn't notice and didn't re-code them to make sure they were all the same, this means that I think we over-adjusted the original analysis in the transient part of the model.  Cleaning this up strengthens the  results obtained using the original dataset by about 1 unit/year for PM2.5 and 2 units/year for NOx.

Smoking: Smoking was supposed to be coded as 5 categories: 1) never smoker/no second-hand smoke (SHS) exposure, 2) never/any SHS, 3) current smoker, 4) former/no SHS, 5) former/any SHS.  In the original analysis, I had coded smoking as the interaction between smoking status and second-hand smoke since this should have produced an exactly equivalent result.  However, I think I missed re-coding the SHS at some of the exams, since both smoking status and SHS were covered by a slightly different collection of variables at each exam.  This doesn't impact the final result very much, about 0.4 units/year for PM2.5, but I wanted to provide clearer coding for the Biolincc analysis.

Different analysis software: The original analysis used the HPMIXED procedure in SAS.  A contemporary re-analysis in R showed results that were within several hundredths of the original effect estimates.

_Note as of 11/22/2023, some of the datasets that were supposed to be released to BioLINCC are missing, so I'm working with the CC to make sure those are included presently_
