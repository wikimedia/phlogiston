## Convert a historical transaction file from Phab into a burnup report

library(dplyr)
library(reshape2)
library(ggplot2)
library(scales)

phab_data=read.csv("VE-report.csv")

## data prep

phab_summ = group_by(phab_data, Date, Project)
phab_summ = summarize(phab_summ, point_total = sum(Points))
phab_summ$Date <- as.Date(phab_summ$Date, "%Y-%m-%d")

## adjust labels
## http://stackoverflow.com/questions/1828742/rotating-axis-labels-in-r

burnup_output=png(filename = "VE-report.png", width=1000, height=700, units="px", pointsize=12)
ggplot(phab_summ, aes(x = Date, y = point_total, group=Project, fill=Project)) + geom_area(position='stack')
dev.off()

##
## ggplot(phab_summ, aes(x = Date, y = point_total, group=point_total, fill=Project)) + geom_area(position='stack') + scale_x_date(breaks="1 month", label=date_libraformat("%Y-%b"), limits = as.Date(c('2015-01-01', '2015-01-05')))


## ggplot(phab_summ, aes(x = Date, y = point_total, group=point_total, fill=Project)) + geom_area(position='stack')

## phab_summ_t = dcast(phab_summ, Date ~ Project)

## velocity = group_by(phab_data, Date, Status)

## velocity = summarize(velocity, point_total = sum(Points))

## velocityT = dcast(velocity, Date ~ Status)

## write.csv(VelocityT, file="velocity.csv")
## write.csv(phab_summ_t, file="backlog.csv")


