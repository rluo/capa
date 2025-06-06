#' @useDynLib capp, .registration = TRUE
#' @importFrom Rcpp sourceCpp

#' @title Flury's Common Principal Component Analysis
#'
#' @description
#' Common principal component Analysis (copied from non-maintained pkg multigroup)
#'
#' @param Data a numeric matrix or data frame
#' @param Group a vector of factors associated with group structure
#' @param Scale scaling variables, by default is False. By default data are centered within groups.
#' @param graph should loading and component be plotted
#' @return list with the following results:
#' @return \item{Data}{Original data}
#' @return \item{Con.Data}{Concatenated centered data}
#' @return \item{split.Data}{Group centered data}
#' @return \item{Group}{Group as a factor vector}
#' @return \item{loadings.common}{Matrix of common loadings}
#' @return \item{lambda}{The specific variances of group}
#' @return \item{exp.var}{Percentages of total variance recovered associated with each dimension }
#' @export
#' @references B. N. Flury (1984). Common principal components in k groups.
#'  \emph{Journal of the American Statistical Association}, 79, 892-898.
#'
#' A. Eslami, E. M. Qannari, A. Kohler and S. Bougeard (2013). General overview
#'  of methods of analysis of multi-group datasets,
#'  \emph{Revue des Nouvelles Technologies de l'Information}, 25, 108-123.
#'
#'
#' @examples
#' Data <- iris[, -5]
#' Group <- iris[, 5]
#' res.FCPCA <- FCPCA(Data, Group, graph = TRUE)
#' loadingsplot(res.FCPCA, axes = c(1, 2))
#' scoreplot(res.FCPCA, axes = c(1, 2))
FCPCA <- function(Data, Group, Scale = FALSE, graph = FALSE) {
    # ============================================================================
    #                             1. Checking the inputs
    # ============================================================================
    input_check(Data, Group)


    # ============================================================================
    #                              2. preparing Data
    # ============================================================================
    if (is.data.frame(Data) == TRUE) {
        Data <- as.matrix(Data)
    }
    if (is.null(colnames(Data))) {
        colnames(Data) <- paste("V", 1:ncol(Data), sep = "")
    }
    Group <- as.factor(Group)



    rownames(Data) <- Group #---- rownames of data=groups
    M <- length(levels(Group)) #----number of groups: M
    P <- dim(Data)[2] #----number of variables: P
    n <- as.vector(table(Group)) #----number of individuals in each group
    N <- sum(n) #----number of individuals
    split.Data <- split(Data, Group) #----split Data to M parts

    # centering and scaling if TRUE
    for (m in 1:M) {
        split.Data[[m]] <- matrix(split.Data[[m]], nrow = n[m])
        split.Data[[m]] <- scale(split.Data[[m]], center = TRUE, scale = Scale)
    }


    # concatinated dataset by row as groups
    Con.Data <- split.Data[[1]]
    for (m in 2:M) {
        Con.Data <- rbind(Con.Data, split.Data[[m]])
    }
    rownames(Con.Data) <- Group
    colnames(Con.Data) <- colnames(Data)


    # Variance-covariance matrix for each group
    cov.Group <- vector("list", M)
    for (m in 1:M) {
        cov.Group[[m]] <- t(split.Data[[m]]) %*% split.Data[[m]] / n[m]
    }

    W <- FG_cpp(cov.Group, 15, P, M)
    # ============================================================================
    #                              4.  Explained variance
    #                              variance of each loading
    #                lambda = t(common loading)*(t(Xm)* Xm) * common loading
    # ============================================================================
    lambda <- matrix(0, nrow = M, ncol = P)
    for (m in 1:M) {
        lambda[m, ] <- round(diag(t(W) %*% cov.Group[[m]] %*% W), 3)
    }



    # ============================================================================
    #    			                      5. Outputs
    # ============================================================================
    res <- list(
        Data = Data,
        Con.Data = Con.Data,
        split.Data = split.Data,
        Group = Group
    )



    res$loadings.common <- W
    rownames(res$loadings.common) <- colnames(Data)
    colnames(res$loadings.common) <- paste("Dim", 1:P, sep = "")

    res$lambda <- lambda
    rownames(res$lambda) <- levels(Group)
    colnames(res$lambda) <- paste("Dim", 1:P, sep = "")


    ncomp <- ncol(res$lambda)
    exp.var <- matrix(0, M, ncomp)
    for (m in 1:M) {
        exp.var[m, ] <- 100 * lambda[m, ] / sum(diag(cov.Group[[m]]))
    }
    res$exp.var <- exp.var
    rownames(res$exp.var) <- levels(Group)
    colnames(res$exp.var) <- paste("Dim", 1:ncomp, sep = "")

    if (graph) {
        plot.mg(res)
    }

    class(res) <- c("FCPCA", "mg")
    return(res)
}


#' @S3method print FCPCA
print.FCPCA <- function(x, ...) {
    cat("\nCommon Principal Component Analysis\n")
    cat(rep("-", 43), sep = "")
    cat("\n$lambda            ", "variance for each group")
    cat("\n$loadings.common   ", "common loadings")
    cat("\n$Data              ", "Data set")
    cat("\n")
    invisible(x)
}
