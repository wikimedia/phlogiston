## Graph Phlogiston csv reports as charts

library(ggplot2)
library(scales)
library(RColorBrewer)

######################################################################
## Backlog
######################################################################

backlog <- read.csv("/tmp/col_backlog.csv")
backlog$date <- as.Date(backlog$date, "%Y-%m-%d")
backlog_output=png(filename = "~/html/col_backlog_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup <- read.csv("/tmp/col_burnup.csv")
burnup$date <- as.Date(burnup$date, "%Y-%m-%d")

ggplot(backlog) +
  labs(title="Collaboration backlog", y="Story Point Total") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = points, group=category, fill=category, order=-as.numeric(category))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b")) +
  geom_line(data=burnup, aes(x=date, y=points), size=2)
dev.off()

backlog_count <- read.csv("/tmp/col_backlog_count.csv")
backlog_count$date <- as.Date(backlog_count$date, "%Y-%m-%d")
backlog_count_output=png(filename = "~/html/col_backlog_count_burnup.png", width=2000, height=1125, units="px", pointsize=30)

burnup_count <- read.csv("/tmp/col_burnup_count.csv")
burnup_count$date <- as.Date(burnup_count$date, "%Y-%m-%d")

ggplot(backlog_count) +
  labs(title="Collaboration backlog", y="Task Count") +
  theme(text = element_text(size=30), legend.title=element_blank())+
  geom_area(position='stack', aes(x = date, y = count, group=category, fill=category, order=-as.numeric(category))) +
  scale_x_date(breaks="1 month", label=date_format("%Y-%b")) +
  geom_line(data=burnup_count, aes(x=date, y=count), size=2)
dev.off()


######################################################################
## Maintenance Fraction
######################################################################

col_maint_frac <- read.csv("/tmp/col_maintenance_fraction.csv")
col_maint_frac$date <- as.Date(col_maint_frac$date, "%Y-%m-%d")

status_output <- png(filename = "~/html/col_maint_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
ggplot(col_maint_frac, aes(date, maint_frac)) +
  labs(title="Collaboration Maintenance Fraction", y="Fraction of completed work that is maintenance") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30)) +
  scale_y_continuous(labels=percent, limits=c(0,1))
dev.off()

col_maint_count_frac <- read.csv("/tmp/col_maintenance_count_fraction.csv")
col_maint_count_frac$date <- as.Date(col_maint_count_frac$date, "%Y-%m-%d")

status_output_count <- png(filename = "~/html/col_maint_count_frac.png", width=2000, height=1125, units="px", pointsize=30)
  
ggplot(col_maint_count_frac, aes(date, maint_frac)) +
  labs(title="Collaboration Maintenance Fraction (by count instead of points)", y="Fraction of completed work that is maintenance") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30)) +
  scale_y_continuous(labels=percent, limits=c(0,1))
dev.off()

######################################################################
## Velocity
######################################################################

velocity <- read.csv("/tmp/col_velocity.csv")
velocity$date <- as.Date(velocity$date, "%Y-%m-%d")

velocity_output <- png(filename = "~/html/col_velocity.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity, aes(date, velocity)) +
  labs(title="Velocity per week", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

velocity_count <- read.csv("/tmp/col_velocity_count.csv")
velocity_count$date <- as.Date(velocity_count$date, "%Y-%m-%d")

velocity_count_output <- png(filename = "~/html/col_velocity_count.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(velocity_count, aes(date, velocity)) +
  labs(title="Velocity per week", y="Tasks") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Velocity vs backlog
######################################################################

net_growth <- read.csv("/tmp/col_net_growth.csv")
net_growth$date <- as.Date(net_growth$date, "%Y-%m-%d")

net_growth_output <- png(filename = "~/html/col_net_growth.png", width=2000, height=1125, units="px", pointsize=30)

ggplot(net_growth, aes(date, points)) +
  labs(title="Net change in open backlog", y="Story Points") +
  geom_bar(stat="identity") +
  theme(text = element_text(size=30))
dev.off()

######################################################################
## Recently Closed
######################################################################

done <- read.csv("/tmp/col_recently_closed.csv")
done$date <- as.Date(done$date, "%Y-%m-%d")

done_output <- png(filename = "~/html/col-done.png", width=2000, height=1125, units="px", pointsize=30)
ggplot(done, aes(x=date, y=points, fill=factor(category), order=-as.numeric(category))) +
  labs(title="Collaboration Completed work", y="Points", x="Month", aesthetic='Milestone') +
  theme(text = element_text(size=30)) +
  geom_bar(stat="identity", width=17) +
  scale_fill_discrete(name="Milestones")
dev.off()
