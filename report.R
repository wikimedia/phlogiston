## Convert a historical transaction file from Phab into a burnup report

library(dplyr)
library(reshape2)
library(ggplot2)
library(scales)

phab_data=read.csv("VE_backlog.csv")

## Backlog

phab_group = group_by(phab_data, Date, Project)
phab_summ = summarize(phab_group, point_total = sum(Points))
phab_summ$Date <- as.Date(phab_summ$Date, "%Y-%m-%d") ## convert string to date
phab_summ$Project2 <- factor(phab_summ$Project, levels = c("VisualEditor","VisualEditor 2015/16 Q1 blockers","VisualEditor 2014/15 Q4 blockers","VisualEditor 2014/15 Q3 blockers"))

phab_burn=read.csv("VE_burnup.csv")

burnup_output=png(filename = "VE-report.png", width=2000, height=1400, units="px", pointsize=30)

ggplot(phab_summ,
       aes(x = Date, y = point_total, group=Project2, fill=Project2, order=-as.numeric(Project2))) +
    labs(title="VE backlog", y="Story Count") +
    geom_area(position='stack') +
    scale_x_date(breaks="1 month", label=date_format("%Y-%b"), limits = as.Date(c('2014-11-01', '2015-06-30'))) +
    scale_y_continuous(limits=c(0, 60000))
par(new=T)
plot(phab_burn$Date, phab_burn$point_total, axes=F, ylim=c(0,60000))
par(new=F)
dev.off()

##
##point_hist=read.csv("/tmp/histogram.csv");
##point_hist_wide <- dcast(point <- hist, points + project ~ category, value.var="count")


## ggplot(phab_summ, aes(x = Date, y = point_total, group=point_total, fill=Project)) + geom_area(position='stack')

## phab_summ_t = dcast(phab_summ, Date ~ Project)

## velocity = group_by(phab_data, Date, Status)

## velocity = summarize(velocity, point_total = sum(Points))

## velocityT = dcast(velocity, Date ~ Status)

## write.csv(VelocityT, file="velocity.csv")
## write.csv(phab_summ_t, file="backlog.csv")


