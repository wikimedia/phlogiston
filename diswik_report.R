## Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)

######################################################################
## Backlog
######################################################################

backlog <- read.csv("/tmp/diswik_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
backlog_output=png(filename = "~/html/diswik_backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup <- read.csv("/tmp/diswik_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")

ggplot(backlog) +
  labs(title="Discovery Wikidata Query Service backlog", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-as.numeric(category))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b")) +
  geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

backlog_count <- read.csv("/tmp/diswik_backlog_count.csv")
backlog_count$date <- as.Date(backlog_count$date, "%Y-%m-%d")
backlog_count_output=png(filename = "~/html/diswik_backlog_count_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup_count <- read.csv("/tmp/diswik_burnup_count.csv")
burnup_count$date <- as.Date(burnup_count$date, "%Y-%m-%d")

ggplot(backlog_count) +
  labs(title="Discovery Wikidata Query Service backlog", y="Task Count") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-as.numeric(category))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b")) +
  geom_line(data=burnup_count, aes(x=date, y=count), size=2)
dev.off()


## ######################################################################
## ## Maintenance Fraction
## ######################################################################

## diswik_maint_frac <- read.csv("/tmp/diswik_maintenance_fraction.csv")
## diswik_maint_frac$date <- as.Date(diswik_maint_frac$date, "%Y-%m-%d")

## status_output <- png(filename = "~/html/diswik_maint_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(diswik_maint_frac, aes(date, maint_frac)) +
##   labs(title="VE Maintenance Fraction", y="Fraction of completed work that is maintenance") +
##   geom_bar(stat="identity") +
##   theme(text = element_text(size=30)) +
##   scale_y_continuous(labels=percent, limits=c(0,1))
## dev.off()

## diswik_maint_count_frac <- read.csv("/tmp/diswik_maintenance_count_fraction.csv")
## diswik_maint_count_frac$date <- as.Date(diswik_maint_count_frac$date, "%Y-%m-%d")

## status_output_count <- png(filename = "~/html/diswik_maint_count_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
## ggplot(diswik_maint_count_frac, aes(date, maint_frac)) +
##   labs(title="Discovery Wikidata Query Service Maintenance Fraction (by count instead of points)", y="Fraction of completed work that is maintenance") +
##   geom_bar(stat="identity") +
##   theme(text = element_text(size=30)) +
##   scale_y_continuous(labels=percent, limits=c(0,1))
## dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv("/tmp/diswik_velocity.csv")
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

velocity_output <- png(filename = "~/html/diswik_velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, velocity)) +
  labs(title="Velocity per week", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

velocity_count <- read.csv("/tmp/diswik_velocity_count.csv")
velocity_count$date <- as.Date(velocity_count$date, "%Y-%m-%d")

velocity_count_output <- png(filename = "~/html/diswik_velocity_count.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity_count, aes(date, velocity)) +
  labs(title="Velocity per week", y="Tasks") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth <- read.csv("/tmp/diswik_net_growth.csv")
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output <- png(filename = "~/html/diswik_net_growth.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, points)) +
  labs(title="Net change in open backlog", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Forecast
######################################################################
## For now, plot manually collected data.

case <- c("Pess","Nom","Opt","Pess","Nom","Opt")
foredate <- c("2015-08-12","2015-08-12","2015-08-12","2015-09-21","2015-09-21","2015-09-21")
date <- c("2016-03-21","2015-10-15","2015-09-25","2015-11-27","2015-10-15","2015-10-01")

minmax <- c("2015-08-01","2016-04-01")

line45 <- data.frame( x = c(0,1), y=c(0,1))
##line45$x <- as.Date(line45$x, format="Y%-%m-%d")
##line45$y <- as.Date(line45$y, format="Y%-%m-%d")

forecast <- data.frame(case, foredate, date)
forecast$foredate <- as.Date(forecast$foredate, format = "%Y-%m-%d")
forecast$date <- as.Date(forecast$date, format = "%Y-%m-%d")

forecast_output <- png(filename = "~/html/diswik_forecast.png", width=2000, height=2000, units="px", pointsize=30)

ggplot(forecast, aes(x=foredate, y=date, group=case)) +
  geom_line(shape=1) +
  labs(title="Discovery Wikidata Query Service Forecasting History", x="Now", y="Forecast Completion") +
  scale_x_date(limits = c(as.Date("2015-08-01"), as.Date("2016-04-01"))) +
  scale_y_date(limits = c(as.Date("2015-08-01"), as.Date("2016-04-01"))) +
  theme(text = element_text(size=30))  + 
  geom_abline(intercept = 0, slope=1, color="darkgray")
dev.off()

######################################################################
## Recently Closed
######################################################################

done <- read.csv("/tmp/diswik_recently_closed.csv")
done$date <- as.Date(done$date, "%Y-%m-%d")

done_output <- png(filename = "~/html/diswik_done.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=points, fill=factor(category), order=-as.numeric(category))) +
  labs(title="Discovery Wikidata Query Service Completed work", y="Points", x="Month", aesthetic='Milestone') +
  theme(text = element_text(size=30)) +
  geom_bar(stat="identity", width=17) +
  scale_fill_discrete(name="Milestones")
dev.off()
