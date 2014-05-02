#!/usr/bin/env Rscript

data <- read.table('whoscloggin.in', header=T)
data$user <- lapply(data$user, as.character)

gen.plot <- function( sorted.data, metric, output.file ) {
    ### add in cumulative SUs and percents
    sorted.data$cumul.q <- cumsum(sorted.data[, metric])
    sorted.data$pct <- sorted.data[,metric] / sum(sorted.data[,metric])
    sorted.data$cumul.pct <- cumsum(sorted.data$pct)

    ### final row of the data frame containing the sum of each column
    sorted.data.sums <- c( 'total', colSums(sorted.data[,2:10]) )

    ### plot.data is only the top X people.  X is either 9 OR the top 90% of 
    ### consumers (whichever is smaller)
    idx <- sorted.data$cumul.pct < 0.90
    if ( sum(idx) > 9 ) {
        len.of.list <- length(idx)
        if ( len.of.list > 9 ) { 
          idx <- c( rep(TRUE,9), rep(FALSE,len.of.list - 9) )
        } else {
          idx <- rep(TRUE,9)
        }
    } else if ( sum(idx) == 0 ) {
      idx <- sorted.data[,metric] > 0
    }
    plot.data <- sorted.data[idx,]
    
    ### the total sum of each column of the data shown
    plot.sums <- c( 'shown', colSums(plot.data[,2:10]) )
    
    ### this is the total sum of each column minus the sum of what we're showing 
    ### to get the sum of the remaining data not shown
    plot.remainder <- c( 0.0, as.numeric(sorted.data.sums[2:10])  - as.numeric(plot.sums[2:10]) )
    
    ### add that final "remainder" row to the data to be plotted
    plot.data <- rbind( plot.data, as.numeric(plot.remainder) )
    plot.data[nrow(plot.data),1] <- "Other users"
    
    ### generate labels based on user and their percent contribution
    #plot.labels <- paste(plot.data$user, ', ', round(plot.data$pct*100), '%', sep="")
    plot.labels <- paste(plot.data$user, ', ', round(plot.data[,metric]/1000), 'k', sep="")
    
    ### finally generate the plot
    png(output.file, width=640, height=480, bg='transparent')
    par(new=F, mar=c(0, 0, 0, 0))
    pie(plot.data[, metric],labels=plot.labels, col=rainbow(nrow(plot.data)))
    dev.off()
}


### sorted dataframe
sorted.data <- data[with(data, order(-SUs.q)), ]
gen.plot( sorted.data, 'SUs.q', 'whoscloggin.png' )

### sorted dataframe
sorted.data <- data[with(data, order(-SUs)), ]
gen.plot( sorted.data, 'SUs', 'whosusin.png' )
