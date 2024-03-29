#' Imputation of Missing Values
#'
#' \code{missing_values()} imputes missing values in metabolmics data matrices
#'
#' @param inputdata A data frame in the correct format.
#' @param column.cutoff A value between zero and one. If the proportion of
#' missing values is equal to or more than the column.cutoff in all groups, that
#' whole column will be deleted.
#' @param group.cutoff A value between zero and one. If the proportion of
#' missing values in a group is equal to or more than the group.cutoff, those
#' missing values will be replaced by a random number between zero and the
#' minimum of the entire matrix.
#' @param complete.matrix A logical indicating whether a complete matrix is
#' required. If \code{TRUE}, the remaining missing values (preferably only a
#' very few) will be replaced by the average of the abundances in the rest of
#' the group.
#' @param seed An integer to set the state of random number generation.
#' @param saveoutput A logical indicating whether the output should be saved.
#' If \code{TRUE}, the results will be saved as a csv file..
#' @param outputname The name of the output file.
#'
#' @return returns an object with class \code{metabdata}.
#'
#' @note This function was copied from the now deprecated \code{metabolomics}
#' package. Authors listed below.
#'
#' @seealso
#' \href{https://github.com/cran/metabolomics}{metabolomics}
#'
#' @author Alysha M De Livera
#' @author Jairus Brown
#'
#' @import stats
#'
#' @export
#'


missing_values <-function(inputdata, column.cutoff=NULL, group.cutoff=NULL,
                          complete.matrix=FALSE, seed=100, saveoutput=FALSE,
                          outputname="missing.values.rep")
  {
  set.seed(seed)
  inputdata <- cbind(row.names(inputdata), inputdata)

  if (is.null(column.cutoff)) {
    stop("Enter a column cut-off")
  }

  if (is.null(group.cutoff)) {
    stop("Enter a group cut-off")
  }

  warning("If the data contains a large proportion of missing values, please try
          to reduce the number of missing values in the preprocessing step."
          )

  # Get base information
  groups <- levels(factor(inputdata[, 2], levels=unique(inputdata[, 2])))
  vars <- colnames(inputdata)[3:length(colnames(inputdata))]
  row_count <- dim(inputdata)[1]
  matrix_min <- min(inputdata[, -c(1:2)], na.rm=TRUE)

  # Set a default cutoff so that it may be changed as necessary (col, group)
  write(' -> Checking columns...', '')

  # Delete any columns that are entirely missing
  mt_cols<-which(colSums(is.na(inputdata)) == row_count)
  if (length(mt_cols) > 0) {
    pretrim_data <- inputdata[, -c(mt_cols)]
  } else {
    pretrim_data <- inputdata
  }

  write(' -> Checking groups...', '')

  # Check number of missing values for each group
  trim_data <- pretrim_data[, c(1:2)]
  for (jj in 3:length(colnames(pretrim_data))) {
    gr_counter = 0
    for (group in groups) {
      rows_curr <- which(pretrim_data[, 2] == group)
      gr_missing <- length(which(is.na(pretrim_data[rows_curr, jj])))
      if (gr_missing >= ceiling(column.cutoff * (length(rows_curr)))) {
        gr_counter <- gr_counter + 1
      }
    }
    if (gr_counter != length(groups)) {
      trim_data <- cbind(trim_data, pretrim_data[, jj])
      new_colnames <- colnames(pretrim_data)[jj]
      colnames(trim_data)[length(colnames(trim_data))] <- new_colnames
    }
  }
  rownames(trim_data) <- rownames(pretrim_data)

  # For the remaining data, check Z-scores
  out_data <- data.frame()
  out_z <- data.frame()
  for (group in groups) {
    l_gr <- length(groups)
    gr_num <- which(groups == group)

    # Collect a single-group subset of the data
    g_trim_data <- trim_data[which(trim_data[, 2] == group), ]
    g_row_count <- dim(g_trim_data)[1]
    met_cols <- c(3:dim(g_trim_data)[2])

    # List columns that still have missing values
    col_idx <- which(colSums(is.na(g_trim_data))!=0)
    write(
      paste(' -> Filling in missing values for ',
            group, ' [', gr_num, '/', l_gr, ']', sep=''
      ), ''
    )

    for (jj in col_idx) {
      # If more than 60% missing, replace with rep1 or half matrix min
      col_mt <- is.na(g_trim_data[jj])
      if (colSums(col_mt) >= group.cutoff * g_row_count) {
        if(matrix_min< 0)
          stop("The data contains negative values.")
        rep1 <- runif(length(which(col_mt == TRUE)), 0, matrix_min)
        g_trim_data[which(col_mt == TRUE), jj] <- rep1
        # Otherwise replace it with rep2 or the mean
      } else if (complete.matrix) {
        rep2 <- mean(g_trim_data[, jj], na.rm=TRUE)
        g_trim_data[which(col_mt == TRUE), jj] <- rep2
      }
    }
    # Attach subset to output data
    out_data <- rbind(out_data, g_trim_data)
  }

  # Edit the column names if necessary
  colnames(out_data) <- if (
    length(grep("^X[\\d]", colnames(out_data), perl=TRUE)) != 0
  ) {
    gsub("^X([\\d].*)", "\\1", colnames(out_data), perl=TRUE)
  } else {
    colnames(out_data)
  }
  write(' -> Done!', '')

  if (saveoutput) {
    utils::write.csv(out_data[, -1], paste(c(outputname, ".csv"), collapse=""))
  }
  output <- c()
  output$output <- out_data[, -1]
  output$groups <- groups
  output$samples <- row.names(inputdata)

  return(structure(output, class = "metabdata"))
}
