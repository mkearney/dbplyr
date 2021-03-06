context("test-lazy-ops.R")

# op_vars -----------------------------------------------------------------

test_that("select reduces variables", {
  out <- mtcars %>% tbl_lazy() %>% select(mpg:disp)
  expect_equal(op_vars(out), c("mpg", "cyl", "disp"))
})

test_that("rename preserves existing", {
  out <- data_frame(x = 1, y = 2) %>% tbl_lazy() %>% rename(z = y)
  expect_equal(op_vars(out), c("x", "z"))
})

test_that("mutate adds new", {
  out <- data_frame(x = 1) %>% tbl_lazy() %>% mutate(y = x + 1, z = y + 1)
  expect_equal(op_vars(out), c("x", "y", "z"))
})

test_that("summarise replaces existing", {
  out <- data_frame(x = 1, y = 2) %>% tbl_lazy() %>% summarise(z = 1)
  expect_equal(op_vars(out), "z")
})

test_that("transmute replaces existing", {
  out <- data_frame(x = 1, y = 2) %>% tbl_lazy() %>% transmute(z = 1)
  expect_equal(op_vars(out), "z")
})

test_that("summarised and mutated vars are always named", {
  mf <- dbplyr::memdb_frame(a = 1)

  out1 <- mf %>% summarise(1) %>% op_vars()
  expect_equal(out1, "1")

  out2 <- mf %>% mutate(1) %>% op_vars()
  expect_equal(out2, c("a", "1"))
})

test_that("distinct has complicated rules", {
  out <- lazy_frame(x = 1, y = 2) %>% distinct()
  expect_equal(op_vars(out), c("x", "y"))

  out <- lazy_frame(x = 1, y = 2) %>% distinct(x, .keep_all = TRUE)
  expect_equal(op_vars(out), c("x", "y"))

  out <- lazy_frame(x = 1, y = 2, z = 3) %>% distinct(x, y)
  expect_equal(op_vars(out), c("x", "y"))

  out <- lazy_frame(x = 1, y = 2, z = 3) %>% group_by(x) %>% distinct(y)
  expect_equal(op_vars(out), c("x", "y"))
})

test_that("grouped summary keeps groups", {
  out <- data_frame(g = 1, x = 1) %>%
    tbl_lazy() %>%
    group_by(g) %>%
    summarise(y = 1)
  expect_equal(op_vars(out), c("g", "y"))
})

test_that("joins get vars from both left and right", {
  out <- left_join(
    lazy_frame(x = 1, y = 1),
    lazy_frame(x = 2, z = 2),
    by = "x"
  )

  expect_equal(op_vars(out), c("x", "y", "z"))
})

test_that("semi joins get vars from left", {
  out <- semi_join(
    lazy_frame(x = 1, y = 1),
    lazy_frame(x = 2, z = 2),
    by = "x"
  )

  expect_equal(op_vars(out), c("x", "y"))
})


# op_grps -----------------------------------------------------------------

test_that("group_by overrides existing groups", {
  df <- data_frame(g1 = 1, g2 = 2, x = 3) %>% tbl_lazy()

  out1 <- df %>% group_by(g1)
  expect_equal(op_grps(out1), "g1")

  out2 <- out1 %>% group_by(g2)
  expect_equal(op_grps(out2), "g2")
})

test_that("group_by increases grouping if add = TRUE", {
  df <- data_frame(g1 = 1, g2 = 2, x = 3) %>% tbl_lazy()

  out <- df %>% group_by(g1) %>% group_by(g2, add = TRUE)
  expect_equal(op_grps(out), c("g1", "g2"))
})

test_that("rename renames grouping vars", {
  df <- lazy_frame(a = 1, b = 2) %>% group_by(a) %>% rename(c = a)
  expect_equal(op_grps(df), "c")
})

test_that("summarise drops one grouping level", {
  df <- data_frame(g1 = 1, g2 = 2, x = 3) %>% tbl_lazy() %>% group_by(g1, g2)
  out1 <- df %>% summarise(y = 1)
  out2 <- out1 %>% summarise(y = 2)

  expect_equal(op_grps(out1), "g1")
  expect_equal(op_grps(out2), character())
})

test_that("ungroup drops all groups", {
  out1 <- lazy_frame(g1 = 1, g2 = 2) %>%
    group_by(g1, g2) %>%
    ungroup()

  out2 <- lazy_frame(g1 = 1, g2 = 2) %>%
    group_by(g1, g2) %>%
    ungroup() %>%
    rename(g3 = g1)

  expect_equal(op_grps(out1), character())
  expect_equal(op_grps(out2), character())
})

# op_sort -----------------------------------------------------------------

test_that("unsorted gives NULL", {
  out <- lazy_frame(x = 1:3, y = 3:1)
  expect_equal(op_sort(out), NULL)
})

test_that("arranges captures DESC", {
  out <- lazy_frame(x = 1:3, y = 3:1) %>% arrange(desc(x))

  expect_equal(op_sort(out), list(~desc(x)))
})

test_that("multiple arranges combine", {
  out <- lazy_frame(x = 1:3, y = 3:1) %>% arrange(x) %>% arrange(y)
  out <- arrange(arrange(lazy_frame(x = 1:3, y = 3:1), x), y)

  expect_equal(op_sort(out), list(~x, ~y))
})

test_that("preserved across compute and collapse", {
  df1 <- memdb_frame(x = sample(10)) %>% arrange(x)

  df2 <- compute(df1)
  expect_equal(op_sort(df2), list(~x))

  df3 <- collapse(df1)
  expect_equal(op_sort(df3), list(~x))
})

# head --------------------------------------------------------------------

test_that("two heads are equivalent to one", {
  out <- lazy_frame(x = 1:10) %>% head(3) %>% head(5)
  expect_equal(out$ops$args$n, 3)
})
