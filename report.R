## Convert a historical transaction file from Phab into a burnup report

library(dplyr)
library(reshape2)

phab_data=read.csv("VE-report.csv")
phab_summ = group_by(phab_data, Date, Project)
phab_summ = summarize(phab_summ, point_total = sum(Points))
phab_summ_t = dcast(phab_summ, Date ~ Project)
write.csv(VelocityT, file="velocity.csv")
write.csv(phab_summ_t, file="backlog.csv")
