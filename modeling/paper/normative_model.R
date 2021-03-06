
library(tidyverse)

rm(list=ls())
load('paper/hypos.Rdata')
load('../behavioral_data/tasks.Rdata')
load('../behavioral_data/aggregated.Rdata')
df.sels<-df.sels %>% filter(sequence=='combined')

source('paper/shared.R')

# Causal categories
alpha=2.41
beta=938.81
gamma=0.5
t=9.44

get_model_preds<-function(alpha, beta, t='', gamma) {
  model.cat<-data.frame(
    learningTaskId=character(0), trial=numeric(0),
    object=character(0), prob=numeric(0), prob_s=numeric(0)
  )
  # CRP priors - fixed for this setup
  crp_join<-alpha/(alpha+1)
  crp_new<-1/(alpha+1)
  # Predictions
  for (i in seq(6)) {
    cond<-paste0('learn0', i)
    post_col<-paste0('post_l',i)
    learn_task<-tasks %>% filter(phase=='learn', learningTaskId==cond) %>%
      select(agent, recipient, result) %>% as.list()
    for (j in seq(15)) {
      task_data<-tasks %>% 
        filter(phase=='gen', learningTaskId==cond, trial==j) %>%
        select(agent, recipient) %>% paste0(., collapse=',')
      # Dir likelihoods
      feats<-read_data_feature(task_data, gamma)
      cat_join<-Map('+', init_feat_dist(beta), read_data_feature(learn_task, gamma))
      cat_new<-Map('+', init_feat_dist(beta), feats)
      dir_join<-Reduce('+', Map('*', feats, cat_join))/Reduce('+',cat_join)
      dir_new<-Reduce('+', Map('*', feats, cat_new))/Reduce('+',cat_new)
      # Mix
      mix<-normalize(c(crp_join*dir_join, crp_new*dir_new))
      ll<-likelis[[cond]][[j]]
      preds<-lapply(1:nrow(df.hypos), function(x) {
        Map('+',
            Map('*', ll[[x]], (df.hypos[x,post_col]*mix[1])),
            Map('*', ll[[x]], (df.hypos[x,'prior']*mix[2]))
        )
      }) %>%
        reduce(function(a,b) Map('+', a, b))
      preds.data<-data.frame(object=names(preds), prob=unlist(preds)) %>%
        mutate(learningTaskId=cond, trial=j, prob_s=NA) %>%
        select(learningTaskId, trial, object, prob, prob_s)
      # Fit softmax
      if (typeof(t)=='double') preds.data$prob_s<-softmax(preds.data$prob, t)
      model.cat<-rbind(model.cat, preds.data)
    }
  }
  return(model.cat)
}
# save(model.uni, model.cat, file='models.Rdata')

ggplot(model.cat, aes(x=object, y=trial, fill=prob)) +
  geom_tile() +
  facet_wrap(~learningTaskId) +
  scale_y_continuous(trans="reverse", breaks=1:15) + 
  scale_fill_gradient(low='white', high='#293352')

# Fit parameters: c(alpha=,beta=,t=, g=)
fit_me<-function(par) {
  gamma<-exp(par[4])/(1+exp(par[4]))
  preds<-get_model_preds(par[1],par[2],par[3], gamma)
  ppt<-df.sels %>%
    filter(sequence=='combined') %>%
    select(learningTaskId, trial, object=selection, n)
  data<-preds%>%
    mutate(object=as.character(object)) %>%
    left_join(ppt, by=c('learningTaskId', 'trial', 'object'))
  return(-sum(data$n*log(data$prob_s)))
}
# fit_me(par)

# Gamma = 0.5
out<-optim(par=c(1, 0.1, 1), fit_me, method="L-BFGS-B", lower=c(0, 0, 0))
# par = 2.415026 938.814995   9.437174
# value = 2747.694

# # Gamma = 1
# out2<-optim(par=c(1, 0.1, 1), fit_me, method="L-BFGS-B", lower=c(0, 0, 0))
# # 2.414206 70973.518336     9.437329
# # value = 2747.689
# 
# # Gamma = 0
# out3<-optim(par=c(1, 0.1, 1), fit_me, method="L-BFGS-B", lower=c(0, 0, 0))
# # 3.0802184 0.9406342 9.6247297
# # value = 2742.511
# 
# # Add gamma
# out4<-optim(par=c(1, 0.1, 1, 0), fit_me, method="L-BFGS-B", lower=c(0, 0, 0, -100))
# out4
# # 3.0805175   0.9403594   9.6245604 -15.2928214
# # 2742.511





























