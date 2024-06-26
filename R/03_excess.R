### Monitoring trends and differences in COVID-19 case fatality  ##############
### rates using decomposition methods: A demographic perspective ##############
  
  ### Last updated: 2020-07-15 16:26:50 CEST
  
  ### Contact:
  ### riffe@demogr.mpg.de
  ### acosta@demogr.mpg.de
  ### dudel@demogr.mpg.de
  
  
### Load functions & packages #################################################
  
  source(("R/00_functions.R"))
  

### Load case data ############################################################

  # Load data
  cases <- read_csv("Data/inputdata.csv")
  
  # Edit date
  cases$Date <- as.Date(cases$Date,"%d.%m.%y")
  
  # Lists of countries and regions
  countrylist <- c("China","Germany","Italy","South Korea","Spain","USA")
  regionlist <- c("All")
  
  # Restrict
  cases <- cases %>% filter(Country %in% countrylist & Region %in% regionlist)
  
  # Drop tests
  cases <- cases %>% mutate(Tests=NULL)
  
  
### Load and edit excess mortality data #######################################
  
  # Load CSV file
  dat <- read_csv("Data/baseline_excess_pclm_5.csv")
  
  # Set Date as date
  dat$Date <- as.Date(dat$date,"%d.%m.%y")

  # Restrict
  # Restrict
  dat <- dat %>% filter(Country %in% countrylist) %>% 
    filter(Date >= "2020-02-24")


### Analysis similar to Table 2 ###############################################
  
  # Generate cumulative excess deaths
  dat <- dat %>% 
    mutate(exc_p = ifelse(excess < 0, 0, excess)) %>%
    group_by(Country,Age,Sex) %>% 
    mutate(Exc = cumsum(exc_p)) %>% ungroup()
  
  # Edit age variable
  dat <- dat %>% mutate(Age=recode(Age,
                                   '5'=0,
                                   '15'=10,
                                   '25'=20,
                                   '35'=30,
                                   '45'=40,
                                   '55'=50,
                                   '65'=60,
                                   '75'=70,
                                   '85'=80,
                                   '95'=90))
  
  # Aggregate
  dat <- dat %>% group_by(Country,Sex,Date,Age,Week) %>% 
    select(Exc) %>% summarize_all(sum)
  
  # Adjust date for US: case countrs from two days earlier than excess mortality
  cases$Date[cases$Date=="2020-05-23" & cases$Country=="USA"] <- "2020-05-25"
  
  # Merge with cases
  dat <- inner_join(dat,cases[,c("Country","Date","Age","Sex","Cases")])

  # Calculate ASFRs
  dat <- dat %>% mutate(ascfr = Exc / Cases,
                        ascfr = replace_na(ascfr, 0),
                        ascfr = ifelse(is.infinite(ascfr),0,ascfr),
                        ascfr = ifelse(ascfr>1,1,ascfr))
  
  # Decide some reference patterns (here Germany)
  DE <- dat %>% 
    filter(Country == "Germany",
           Sex == "b",
           #Date == maxdate)
           Week == 19)

  
  # Decompose
  DecDE <- as.data.table(dat)[,
                              kitagawa_cfr(DE$Cases, DE$ascfr,Cases,ascfr),
                              by=list(Country,Week, Sex)]
  
  # Select only most recent date, both genders combined
  DecDE <- DecDE %>% filter(Sex=="b") %>% group_by(Country) %>% filter(Week %in% 19:22)

  # Drop unnecessary variables
  DecDE <- DecDE %>% select(Country,Week,CFR2,Diff,AgeComp,RateComp)

  # Calculate relative contributions
  DecDE <- DecDE %>% mutate(relAgeDE = abs(AgeComp)/(abs(AgeComp)+abs(RateComp)))
  DecDE <- DecDE %>% mutate(relRateDE = abs(RateComp)/(abs(AgeComp)+abs(RateComp)))

  # Rename
  DecDE <- DecDE %>% rename(DiffDE=Diff,AgeCompDE=AgeComp,RateCompDE=RateComp)

  # Sort data
  DecDE <- DecDE %>% arrange(CFR2) # Appendix


### Save extra table ##########################################################
  
  # Appendix table 1
  write_xlsx(x=DecDE,
            path="Output/AppendixTab6.xlsx")
  
