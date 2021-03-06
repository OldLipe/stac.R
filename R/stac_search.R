#' @title Endpoint functions
#'
#' @description (This document is based on STAC specification documentation
#' \url{https://github.com/radiantearth/stac-spec/}
#' and reproduces some of its parts)
#'
#' The \code{stac_search} function implements \code{/stac/search} API endpoint
#' (v0.8.1) and \code{/search} (v0.9.0).
#' It prepares query parameters used in search API request, a
#' \code{stac} object with all filter parameters to be provided to
#' \code{get_request} or \code{post_request} functions. The GeoJSON content
#' returned by these requests is a \code{STACItemCollection} object, a regular R
#' \code{list} representing a STAC Item Collection document.
#'
#' @param q           a \code{RSTACQuery} object expressing a STAC query
#' criteria.
#'
#' @param collections a \code{character} vector of collection IDs to include in
#' the search for items. Only items in one of the provided collections will be
#' searched.
#'
#' @param ids         a \code{character} vector with item IDs. All other filter
#' parameters that further restrict the number of search results are ignored.
#'
#' @param datetime    a \code{character} with a date-time or an interval. Date
#'  and time strings needs to conform RFC 3339. Intervals are expressed by
#'  separating two date-time strings by \code{'/'} character. Open intervals are
#'  expressed by using \code{'..'} in place of date-time.
#'
#' Examples: \itemize{
#'  \item A date-time: \code{"2018-02-12T23:20:50Z"}
#'  \item A closed interval: \code{"2018-02-12T00:00:00Z/2018-03-18T12:31:12Z"}
#'  \item Open intervals: \code{"2018-02-12T00:00:00Z/.."} or
#'  \code{"../2018-03-18T12:31:12Z"} }
#'
#' Only features that have a \code{datetime} property that intersects the
#' interval or date-time informed in \code{datetime} are selected.
#'
#' @param bbox        a \code{numeric} vector with only features that have a
#' geometry that intersects the bounding box are selected. The bounding box is
#' provided as four or six numbers, depending on whether the coordinate
#' reference system includes a vertical axis (elevation or depth):
#' \itemize{ \item Lower left corner, coordinate axis 1
#'           \item Lower left corner, coordinate axis 2
#'           \item Lower left corner, coordinate axis 3 (optional)
#'           \item Upper right corner, coordinate axis 1
#'           \item Upper right corner, coordinate axis 2
#'           \item Upper right corner, coordinate axis 3 (optional) }
#'
#' The coordinate reference system of the values is WGS84 longitude/latitude
#' (\url{http://www.opengis.net/def/crs/OGC/1.3/CRS84}). The values are in
#' most cases the sequence of minimum longitude, minimum latitude, maximum
#' longitude and maximum latitude. However, in cases where the box spans the
#' antimeridian the first value (west-most box edge) is larger than the third
#' value (east-most box edge).
#'
#' @param intersects  a \code{character} value expressing GeoJSON geometries
#' objects as specified in RFC 7946. Only returns items that intersect with
#' the provided polygon.
#'
#' @param limit       an \code{integer} defining the maximum number of results
#' to return. If not informed it defaults to the service implementation.
#'
#' @seealso \code{\link{stac}}, \code{\link{ext_query}},
#' \code{\link{get_request}}, \code{\link{post_request}}
#'
#' @return
#' A \code{RSTACQuery} object with the subclass \code{search} containing all
#' search field parameters to be provided to STAC API web service.
#'
#' @examples
#' \donttest{
#' # GET request
#' stac("https://brazildatacube.dpi.inpe.br/stac/") %>%
#'  stac_search(collections = "CB4_64_16D_STK-1", limit = 10,
#'         datetime = "2017-08-01/2018-03-01") %>%
#'  get_request()
#'
#' # POST request
#' stac("https://brazildatacube.dpi.inpe.br/stac/") %>%
#'  stac_search(collections = "CB4_64_16D_STK-1",
#'         bbox = c(-47.02148, -12.98314, -42.53906, -17.35063)) %>%
#'  post_request()
#' }
#'
#' @export
stac_search <- function(q,
                        collections = NULL,
                        ids = NULL,
                        bbox = NULL,
                        datetime = NULL,
                        intersects = NULL,
                        limit = NULL) {

  # check q parameter
  check_subclass(q, c("stac", "search"))

  params <- list()

  if (!is.null(collections))
    params[["collections"]] <- .parse_collections(collections)

  if (!is.null(ids))
    params[["ids"]] <- .parse_ids(ids)

  if (!is.null(datetime))
    params[["datetime"]] <- .parse_datetime(datetime)

  if (!is.null(bbox))
    params[["bbox"]] <- .parse_bbox(bbox)

  if (!is.null(intersects))
    params[["intersects"]] <- .parse_geometry(intersects)

  if (!is.null(limit) && !is.null(limit))
    params[["limit"]] <- .parse_limit(limit)

  RSTACQuery(version = q$version,
             base_url = q$base_url,
             params = utils::modifyList(q$params, params),
             subclass = "search")
}

#' @export
endpoint.search <- function(q) {

  if (q$version < "0.9.0")
    return("/stac/search")
  return("/search")
}

#' @export
before_request.search <- function(q) {

  check_query_verb(q, verbs = c("GET", "POST"))

  if (!is.null(q$params[["intersects"]]) && q$verb == "GET")
    .error(paste0("Search param `intersects` is not supported by HTTP GET",
                  "method. Try use `post_request` method instead."))

  return(q)
}

#' @export
after_response.search <- function(q, res) {

  content <- content_response(res, "200", c("application/geo+json",
                                            "application/json"))

  RSTACDocument(content = content, q = q, subclass = "STACItemCollection")
}
