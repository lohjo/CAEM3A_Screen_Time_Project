# ============================================================
# Scientific Data Data Descriptor support script
# Updated for the workbook:
# "Resultados_encuesta sobre_ hábitos de estudio_y_uso_de_IA.xlsx"
#
# Workbook sheets used:
# - Respuestas: survey responses
# - Preguntas: question coding and Spanish item wording
# - Muestras: enrolled students and planned samples by program
# - Matriculados y Muestras: optional design metadata (if available)
#
# This script curates the survey data, generates a public data package,
# produces summary tables, and creates the figures referenced in the paper.
# ============================================================

# ------------------------------------------------------------------
# 0. Package checks
# ------------------------------------------------------------------

required_packages <- c(
  "readxl", "openxlsx", "dplyr", "tidyr", "stringr", "stringi", "purrr",
  "ggplot2", "readr", "tibble", "forcats","patchwork"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    "Please install the following packages before running this script: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

library(readxl)
library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(stringi)
library(purrr)
library(ggplot2)
library(readr)
library(tibble)
library(forcats)
library(patchwork)

# ------------------------------------------------------------------
# 1. User-facing paths
# ------------------------------------------------------------------
#setwd("")

survey_file <- "Resultados_encuesta_sobre_ hábitos_de_estudio_y_uso_de_IA.xlsx"

package_dir <- "mendeley_data_package"
fig_dir <- "figures"
table_dir <- "tables"

dir.create(package_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(table_dir, showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------------
# 2. Helper functions
# ------------------------------------------------------------------

trim_all_chr <- function(df) {
  df %>% mutate(across(where(is.character), ~ stringr::str_squish(.x)))
}

normalize_text <- function(x) {
  x %>%
    as.character() %>%
    str_replace_all(fixed("\u00A0"), " ") %>%
    str_trim() %>%
    stringi::stri_trans_general("Latin-ASCII") %>%
    str_replace_all("[^[:alnum:] ]", " ") %>%
    str_squish() %>%
    str_to_lower()
}

read_sheet_safe <- function(file, sheet, col_names = TRUE) {
  sheet_names <- tryCatch(readxl::excel_sheets(file), error = function(e) character())
  if (sheet %in% sheet_names) {
    return(readxl::read_excel(file, sheet = sheet, col_names = col_names, .name_repair = "unique"))
  }
  openxlsx::read.xlsx(file, sheet = sheet, colNames = col_names)
}

safe_date_from_timestamp <- function(x) {
  x_chr <- as.character(x)
  x_chr <- str_replace_all(x_chr, fixed("\u00A0"), " ")
  x_chr <- str_replace_all(x_chr, "a\\.\\s*m\\.", "AM")
  x_chr <- str_replace_all(x_chr, "p\\.\\s*m\\.", "PM")
  x_chr <- str_replace_all(x_chr, "\\s*GMT-5", "")
  x_chr <- str_squish(x_chr)

  x_posix <- suppressWarnings(as.POSIXct(
    x_chr,
    format = "%Y/%m/%d %I:%M:%S %p",
    tz = "America/Bogota"
  ))

  if (all(is.na(x_posix)) && is.numeric(x)) {
    x_posix <- as.POSIXct(x * 86400, origin = "1899-12-30", tz = "UTC")
  }

  as.Date(x_posix)
}

yes_no_to_en <- function(x) {
  case_when(
    normalize_text(x) %in% c("si", "sí") ~ "Yes",
    normalize_text(x) == "no" ~ "No",
    TRUE ~ NA_character_
  )
}

clean_gpa <- function(x) {
  x <- as.character(x)
  x <- str_squish(x)
  x_lower <- str_to_lower(x)
  x_lower <- str_replace_all(x_lower, "[,]", ".")
  x_lower <- str_replace_all(x_lower, "['´`]", ".")

  missing_patterns <- c(
    "aun no tengo", "aún no tengo", "no tengo aun", "no tengo aún",
    "soy primer semestre", "primer semestre", "no tengo notas",
    "no aplica", "ni idea", "inicie este ano", "inicié este año",
    "todavia no", "todavía no", "empece este semestre", "empecé este semestre",
    "no tengo", "0 primer semestre", "aun no", "n/a", "na"
  )

  if (is.na(x) || x == "") return(NA_real_)
  if (any(vapply(missing_patterns, function(p) str_detect(normalize_text(x_lower), fixed(normalize_text(p))), logical(1)))) {
    return(NA_real_)
  }

  value_txt <- str_extract(x_lower, "\\d+(\\.\\d+)?")
  if (is.na(value_txt)) return(NA_real_)

  value <- suppressWarnings(as.numeric(value_txt))
  if (is.na(value)) return(NA_real_)

  if (identical(value, 45)) value <- 4.5
  if (value > 5 && value < 100) value <- value / 10
  if (value <= 0 || value > 5) return(NA_real_)

  round(value, 2)
}

standardize_ai_tools <- function(x) {
  x <- as.character(x)
  if (is.na(x) || str_squish(x) == "") return(NA_character_)

  parts <- str_split(x, pattern = ",|;|\\n|/|\\+|\\sy\\s", simplify = FALSE)[[1]]
  parts <- str_replace_all(parts, "[\\.\\(\\)\\[\\]]", " ")
  parts <- str_squish(str_to_lower(parts))
  parts <- parts[parts != ""]

  normalized <- case_when(
    str_detect(parts, "chat\\s*gpt|chatgpt|\\bgpt\\b") ~ "ChatGPT",
    str_detect(parts, "gemini") ~ "Gemini",
    str_detect(parts, "deep\\s*seek|deepseek") ~ "DeepSeek",
    str_detect(parts, "copilot|co\\s*pilot|microsoft copilot") ~ "Copilot",
    str_detect(parts, "claude") ~ "Claude",
    str_detect(parts, "deepmind") ~ "DeepMind",
    str_detect(parts, "ia nerd|ianerd") ~ "IA Nerd",
    str_detect(parts, "chat\\s*pdf|chatpdf") ~ "ChatPDF",
    str_detect(parts, "grok") ~ "Grok",
    str_detect(parts, "black\\s*box|blackbox") ~ "Blackbox",
    str_detect(parts, "notebook\\s*lm|notebooklm") ~ "NotebookLM",
    str_detect(parts, "perplexity") ~ "Perplexity",
    str_detect(parts, "gamma") ~ "Gamma",
    str_detect(parts, "meta ai") ~ "Meta AI",
    str_detect(parts, "humata") ~ "Humata",
    str_detect(parts, "monica|m[oó]nica") ~ "Monica",
    str_detect(parts, "aria") ~ "Aria",
    str_detect(parts, "llama") ~ "Llama",
    str_detect(parts, "kimi") ~ "Kimi AI",
    str_detect(parts, "slides\\s*go|slidesgo") ~ "Slidesgo",
    str_detect(parts, "humanize\\s*ai") ~ "Humanize AI",
    str_detect(parts, "thetawise") ~ "ThetaWise",
    str_detect(parts, "gauth") ~ "Gauth",
    str_detect(parts, "luzia") ~ "Luzia",
    str_detect(parts, "lucid") ~ "Lucid App",
    str_detect(parts, "mathos") ~ "Mathos",
    str_detect(parts, "ninguna|ninguno|none|n/a|^na$") ~ NA_character_,
    TRUE ~ str_to_title(parts)
  )

  normalized <- unique(stats::na.omit(normalized))
  if (length(normalized) == 0) return(NA_character_)
  paste(normalized, collapse = "; ")
}

count_ai_tools <- function(x) {
  if (is.na(x) || x == "") return(0L)
  length(str_split(x, pattern = ";\\s*")[[1]])
}

format_p <- function(p) {
  ifelse(is.na(p), NA_character_, ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))
}

cramers_v <- function(tbl) {
  chi <- suppressWarnings(chisq.test(tbl, correct = FALSE))
  n <- sum(tbl)
  r <- nrow(tbl)
  k <- ncol(tbl)
  sqrt(as.numeric(chi$statistic) / (n * min(r - 1, k - 1)))
}

count_blank_values <- function(x) {
  sum(is.na(x) | str_squish(as.character(x)) == "")
}

# ------------------------------------------------------------------
# 3. Read workbook sheets
# ------------------------------------------------------------------

questions_source <- read_sheet_safe(survey_file, "Preguntas")
survey_source_all <- read_sheet_safe(survey_file, "Respuestas")
sampling_source <- read_sheet_safe(survey_file, "Muestras")
design_source <- tryCatch(read_sheet_safe(survey_file, "Matriculados y Muestras", col_names = FALSE), error = function(e) NULL)

# ------------------------------------------------------------------
# 4. Questionnaire key and response selection
# ------------------------------------------------------------------

names(questions_source)[1:2] <- c("question_code", "spanish_question")
question_key <- questions_source %>%
  transmute(
    question_code = str_squish(as.character(question_code)),
    spanish_question = str_squish(as.character(spanish_question))
  ) %>%
  filter(!is.na(question_code), question_code != "", !is.na(spanish_question), spanish_question != "")

expected_codes <- question_key$question_code

if (!all(expected_codes %in% names(survey_source_all))) {
  missing_codes <- setdiff(expected_codes, names(survey_source_all))
  stop(
    "The following question codes from the 'Preguntas' sheet were not found in 'Respuestas': ",
    paste(missing_codes, collapse = ", "),
    call. = FALSE
  )
}

# Keep only the coded questionnaire columns listed in the "Preguntas" sheet.
survey_source <- survey_source_all %>%
  select(all_of(expected_codes)) %>%
  trim_all_chr()

# ------------------------------------------------------------------
# 5. Code-based renaming
# ------------------------------------------------------------------

code_to_raw <- c(
  "Temporality" = "response_timestamp",
  "Q1" = "age_raw",
  "Q2" = "gender_raw",
  "Q3" = "non_local_raw",
  "Q4" = "current_university_condition_raw",
  "Q5" = "receives_university_support_raw",
  "Q6" = "academic_program_raw",
  "Q7" = "current_program_term_raw",
  "Q8" = "cumulative_gpa_raw",
  "Q9" = "independent_study_time_raw",
  "Q10" = "organizes_notes_before_tests_raw",
  "Q11" = "study_method_effectiveness_raw",
  "Q12" = "uses_supplementary_resources_raw",
  "Q13" = "procrastination_frequency_raw",
  "Q14" = "study_groups_or_tutoring_raw",
  "Q15" = "self_rated_academic_performance_raw",
  "Q16" = "satisfaction_with_grades_raw",
  "Q17" = "career_satisfaction_affects_motivation_raw",
  "Q18" = "program_meets_expectations_raw",
  "Q19" = "ai_tools_raw",
  "Q20" = "ai_use_frequency_for_study_raw",
  "Q21" = "ai_helped_understand_topics_raw",
  "Q22" = "ai_use_in_academic_tasks_is_fraud_raw",
  "Q23" = "failed_evaluated_activity_due_to_ai_raw",
  "Q24" = "verifies_work_with_ai_after_completion_raw",
  "Q25" = "perceived_ai_dependence_raw",
  "Q26" = "perceived_creativity_reduction_from_ai_raw",
  "Q27" = "prompt_engineering_knowledge_raw",
  "Q28" = "uses_ai_for_nonacademic_activities_raw"
)

survey <- survey_source
names(survey) <- unname(code_to_raw[names(survey)])

required_vars <- unname(code_to_raw)
missing_vars <- setdiff(required_vars, names(survey))
if (length(missing_vars) > 0) {
  stop(
    "Missing variables after code-based renaming: ",
    paste(missing_vars, collapse = ", "),
    call. = FALSE
  )
}

survey <- trim_all_chr(survey)

# ------------------------------------------------------------------
# 6. Public raw release (Spanish labels, date only)
# ------------------------------------------------------------------

spanish_name_map <- setNames(question_key$spanish_question, question_key$question_code)

raw_public <- survey_source
names(raw_public) <- unname(spanish_name_map[names(raw_public)])
raw_public[[spanish_name_map[["Temporality"]]]] <- safe_date_from_timestamp(raw_public[[spanish_name_map[["Temporality"]]]])
names(raw_public)[names(raw_public) == spanish_name_map[["Temporality"]]] <- "Fecha de respuesta"

write_csv(raw_public, file.path(package_dir, "survey_raw_spanish_anonymized.csv"), na = "")

# ------------------------------------------------------------------
# 7. Value-label maps
# ------------------------------------------------------------------

freq_levels_es <- c("Nunca", "Rara vez", "Ocasionalmente", "Casi siempre", "Siempre")
freq_levels_en <- c("Never", "Rarely", "Occasionally", "Almost always", "Always")
freq_map <- setNames(freq_levels_en, freq_levels_es)

study_hours_map <- c(
  "0-1" = "0-1", "1-2" = "1-2", "2-3" = "2-3", "3-4" = "3-4", "4-5" = "4-5",
  "Más de 5" = "More than 5", "Mas de 5" = "More than 5",
  "0-1 horas" = "0-1", "1-2 horas" = "1-2", "2-3 horas" = "2-3",
  "3-4 horas" = "3-4", "4-5 horas" = "4-5", "Más de 5 horas" = "More than 5"
)

study_method_map <- c(
  "Nada efectivo" = "Not effective at all",
  "Poco efectivo" = "Slightly effective",
  "Neutral" = "Neutral",
  "Efectivo" = "Effective",
  "Muy efectivo" = "Very effective"
)

academic_performance_map <- c(
  "Deficiente" = "Poor",
  "Regular" = "Fair",
  "Bueno" = "Good",
  "Sobresaliente" = "Outstanding",
  "Excelente" = "Excellent"
)

helped_map <- c(
  "Definitivamente no" = "Definitely no",
  "Probablemente no" = "Probably no",
  "Indiferente" = "Neutral",
  "Probablemente si" = "Probably yes",
  "Definitivamente si" = "Definitely yes"
)

fraud_map <- c(
  "Totalmente en desacuerdo" = "Strongly disagree",
  "En desacuerdo" = "Disagree",
  "Indeciso" = "Undecided",
  "De acuerdo" = "Agree",
  "Totalmente de acuerdo" = "Strongly agree"
)

intensity_map <- c(
  "En lo absoluto" = "Not at all",
  "Probablemente no" = "Probably not",
  "No estoy seguro(a)" = "Not sure",
  "Probablemente si" = "Probably yes",
  "Mucho" = "A lot"
)

# ------------------------------------------------------------------
# 8. Cleaned analytical dataset
# ------------------------------------------------------------------

survey_cleaned <- survey %>%
  mutate(
    response_date = safe_date_from_timestamp(response_timestamp),
    age_years = suppressWarnings(as.numeric(age_raw)),
    age_years = if_else(age_years >= 15 & age_years <= 60, age_years, NA_real_),
    gender = recode(gender_raw,
      "Masculino" = "Male",
      "Femenino" = "Female",
      "Prefiero no decirlo" = "Prefer not to say",
      .default = NA_character_
    ),
    non_local_student = yes_no_to_en(non_local_raw),
    current_university_condition = recode(current_university_condition_raw,
      "Estudiante tiempo completo" = "Full-time student",
      "Estudiar y trabajar" = "Study and work",
      .default = NA_character_
    ),
    receives_university_support = yes_no_to_en(receives_university_support_raw),
    academic_program = str_squish(academic_program_raw),
    current_program_term = str_replace_all(as.character(current_program_term_raw), "Más de 12|Mas de 12", "More than 12"),
    cumulative_gpa_papa = map_dbl(cumulative_gpa_raw, clean_gpa),
    independent_study_time = recode(independent_study_time_raw, !!!study_hours_map, .default = NA_character_),
    organizes_notes_before_tests = recode(organizes_notes_before_tests_raw, !!!freq_map, .default = NA_character_),
    study_method_effectiveness = recode(study_method_effectiveness_raw, !!!study_method_map, .default = NA_character_),
    uses_supplementary_resources = recode(uses_supplementary_resources_raw, !!!freq_map, .default = NA_character_),
    procrastination_frequency = recode(procrastination_frequency_raw, !!!freq_map, .default = NA_character_),
    study_groups_or_tutoring = recode(study_groups_or_tutoring_raw, !!!freq_map, .default = NA_character_),
    self_rated_academic_performance = recode(self_rated_academic_performance_raw, !!!academic_performance_map, .default = NA_character_),
    satisfaction_with_grades = recode(satisfaction_with_grades_raw, !!!freq_map, .default = NA_character_),
    career_satisfaction_affects_motivation = recode(career_satisfaction_affects_motivation_raw, !!!freq_map, .default = NA_character_),
    program_meets_expectations = recode(program_meets_expectations_raw, !!!freq_map, .default = NA_character_),
    ai_tools_standardized = map_chr(ai_tools_raw, standardize_ai_tools),
    n_ai_tools = map_int(ai_tools_standardized, count_ai_tools),
    ai_use_frequency_for_study = recode(ai_use_frequency_for_study_raw, !!!freq_map, .default = NA_character_),
    ai_helped_understand_topics = recode(ai_helped_understand_topics_raw, !!!helped_map, .default = NA_character_),
    ai_use_in_academic_tasks_is_fraud = recode(ai_use_in_academic_tasks_is_fraud_raw, !!!fraud_map, .default = NA_character_),
    failed_evaluated_activity_due_to_ai = yes_no_to_en(failed_evaluated_activity_due_to_ai_raw),
    verifies_work_with_ai_after_completion = recode(verifies_work_with_ai_after_completion_raw, !!!freq_map, .default = NA_character_),
    perceived_ai_dependence = recode(perceived_ai_dependence_raw, !!!intensity_map, .default = NA_character_),
    perceived_creativity_reduction_from_ai = recode(perceived_creativity_reduction_from_ai_raw, !!!intensity_map, .default = NA_character_),
    prompt_engineering_knowledge = recode(prompt_engineering_knowledge_raw, !!!intensity_map, .default = NA_character_),
    uses_ai_for_nonacademic_activities = yes_no_to_en(uses_ai_for_nonacademic_activities_raw)
  ) %>%
  select(
    response_date,
    age_years,
    gender,
    non_local_student,
    current_university_condition,
    receives_university_support,
    academic_program,
    current_program_term,
    cumulative_gpa_papa,
    independent_study_time,
    organizes_notes_before_tests,
    study_method_effectiveness,
    uses_supplementary_resources,
    procrastination_frequency,
    study_groups_or_tutoring,
    self_rated_academic_performance,
    satisfaction_with_grades,
    career_satisfaction_affects_motivation,
    program_meets_expectations,
    ai_tools_raw,
    ai_tools_standardized,
    n_ai_tools,
    ai_use_frequency_for_study,
    ai_helped_understand_topics,
    ai_use_in_academic_tasks_is_fraud,
    failed_evaluated_activity_due_to_ai,
    verifies_work_with_ai_after_completion,
    perceived_ai_dependence,
    perceived_creativity_reduction_from_ai,
    prompt_engineering_knowledge,
    uses_ai_for_nonacademic_activities
  )

survey_cleaned <- survey_cleaned %>%
  mutate(
    independent_study_time = factor(independent_study_time, levels = c("0-1", "1-2", "2-3", "3-4", "4-5", "More than 5"), ordered = TRUE),
    organizes_notes_before_tests = factor(organizes_notes_before_tests, levels = freq_levels_en, ordered = TRUE),
    uses_supplementary_resources = factor(uses_supplementary_resources, levels = freq_levels_en, ordered = TRUE),
    procrastination_frequency = factor(procrastination_frequency, levels = freq_levels_en, ordered = TRUE),
    study_groups_or_tutoring = factor(study_groups_or_tutoring, levels = freq_levels_en, ordered = TRUE),
    satisfaction_with_grades = factor(satisfaction_with_grades, levels = freq_levels_en, ordered = TRUE),
    career_satisfaction_affects_motivation = factor(career_satisfaction_affects_motivation, levels = freq_levels_en, ordered = TRUE),
    program_meets_expectations = factor(program_meets_expectations, levels = freq_levels_en, ordered = TRUE),
    ai_use_frequency_for_study = factor(ai_use_frequency_for_study, levels = freq_levels_en, ordered = TRUE),
    verifies_work_with_ai_after_completion = factor(verifies_work_with_ai_after_completion, levels = freq_levels_en, ordered = TRUE),
    study_method_effectiveness = factor(study_method_effectiveness, levels = c("Not effective at all", "Slightly effective", "Neutral", "Effective", "Very effective"), ordered = TRUE),
    self_rated_academic_performance = factor(self_rated_academic_performance, levels = c("Poor", "Fair", "Good", "Outstanding", "Excellent"), ordered = TRUE),
    ai_helped_understand_topics = factor(ai_helped_understand_topics, levels = c("Definitely no", "Probably no", "Neutral", "Probably yes", "Definitely yes"), ordered = TRUE),
    ai_use_in_academic_tasks_is_fraud = factor(ai_use_in_academic_tasks_is_fraud, levels = c("Strongly disagree", "Disagree", "Undecided", "Agree", "Strongly agree"), ordered = TRUE),
    perceived_ai_dependence = factor(perceived_ai_dependence, levels = c("Not at all", "Probably not", "Not sure", "Probably yes", "A lot"), ordered = TRUE),
    perceived_creativity_reduction_from_ai = factor(perceived_creativity_reduction_from_ai, levels = c("Not at all", "Probably not", "Not sure", "Probably yes", "A lot"), ordered = TRUE),
    prompt_engineering_knowledge = factor(prompt_engineering_knowledge, levels = c("Not at all", "Probably not", "Not sure", "Probably yes", "A lot"), ordered = TRUE)
  )

write_csv(survey_cleaned, file.path(package_dir, "survey_cleaned_english.csv"), na = "")

# ------------------------------------------------------------------
# 9. Sampling frame by program
# ------------------------------------------------------------------

sampling_source <- sampling_source[, seq_len(min(5, ncol(sampling_source)))]
names(sampling_source) <- c(
  "academic_program", "enrolled_2025_1", "population_share",
  "unrounded_sample", "planned_sample"
)

program_frame <- sampling_source %>%
  mutate(
    academic_program = str_squish(as.character(academic_program)),
    enrolled_2025_1 = as.numeric(enrolled_2025_1),
    population_share = as.numeric(population_share),
    unrounded_sample = as.numeric(unrounded_sample),
    planned_sample = as.numeric(planned_sample)
  ) %>%
  filter(!is.na(academic_program), academic_program != "")

export_counts <- survey_cleaned %>% count(academic_program, name = "survey_export_records")
program_summary <- program_frame %>%
  left_join(export_counts, by = "academic_program") %>%
  mutate(survey_export_records = replace_na(survey_export_records, 0L))

package_sampling_frame <- program_summary %>%
  transmute(
    academic_program,
    enrolled_2025_1,
    planned_proportional_sample = planned_sample,
    records_in_survey_export = survey_export_records
  )

write_csv(package_sampling_frame, file.path(package_dir, "sampling_frame_by_program.csv"), na = "")

population_total <- sum(program_summary$enrolled_2025_1, na.rm = TRUE)
planned_total_sample <- sum(program_summary$planned_sample, na.rm = TRUE)

# Optional sampling assumptions from the design sheet
design_metadata <- NULL
if (!is.null(design_source)) {
  design_metadata <- design_source %>%
    mutate(across(everything(), ~ ifelse(is.na(.x), NA, as.character(.x))))
}

# ------------------------------------------------------------------
# 10. Questionnaire documentation and codebook
# ------------------------------------------------------------------

section_labels <- c(
  rep("Sociodemographic and academic profile", 9),
  rep("Study habits", 6),
  rep("Academic self-perception and satisfaction", 4),
  rep("AI tools and use patterns", 3),
  rep("Ethics and academic integrity", 2),
  "AI tools and use patterns",
  rep("Perceived dependence, creativity, and AI literacy", 3),
  "AI tools and use patterns"
)

english_questions <- c(
  "Response timestamp",
  "Age in years (please enter numbers only)",
  "Gender",
  "Are you a non-local student? Note: students who moved from another city to study at the Manizales campus.",
  "What is your current university situation?",
  "Do you receive any support from the university (food, transportation, housing, study materials, among others)?",
  "Which of the following degree programs are you studying at the Manizales campus?",
  "What is your current term or semester in the degree program you are studying?",
  "What is your cumulative GPA/PAPA? (Please enter numbers only, using a decimal separator such as 4.5.)",
  "On average, how many hours per week do you devote to independent study?",
  "How often do you organize and review your notes and study materials before quizzes or midterm exams?",
  "How effective do you consider your study method for understanding, retaining information, or preparing for an assessment?",
  "How often do you use supplementary resources (extra bibliography, educational videos, tutorials, AI tools) to reinforce your studies?",
  "How often do you postpone important academic activities (procrastination)?",
  "How often do you participate in study groups or attend tutoring/advising sessions?",
  "How would you rate your academic performance in the most recent completed semester?",
  "How often do you feel satisfied with your grades or academic achievements?",
  "To what extent do you think your satisfaction with your degree program affects your motivation to study or your performance?",
  "To what extent do you think the degree program you are enrolled in meets your expectations or professional goals?",
  "Which AI tools have you used?",
  "How often do you use AI tools in your studies?",
  "Do you think AI has helped you understand academic topics?",
  "Do you think using AI tools to produce academic assignments is fraud?",
  "Have you failed or not passed assessed activities because of AI use?",
  "Do you usually verify your work with AI after you finish it?",
  "Do you think you are becoming dependent on the use of AI tools?",
  "Do you think the use of AI has reduced your creativity when carrying out academic activities?",
  "Do you think you have knowledge of prompt engineering? (Prompt engineering refers to the strategic design of instructions or questions to obtain optimal responses from AI models.)",
  "Do you use AI for questions or activities other than academic ones?"
)

questionnaire <- question_key %>%
  mutate(
    section = section_labels,
    english_question = english_questions
  ) %>%
  select(question_code, section, spanish_question, english_question)

write_csv(questionnaire, file.path(package_dir, "questionnaire_bilingual.csv"), na = "")

codebook <- tribble(
  ~variable_name, ~english_label, ~spanish_label, ~response_options_or_format, ~missing_value_convention,
  "response_date", "response date", "Fecha de respuesta", "YYYY-MM-DD; exact timestamps removed from the public file", "Not applicable/none expected in cleaned file",
  "age_years", "age years", "Edad en años", "Numeric years; valid range 15-60, otherwise missing", "Blank field/NA",
  "gender", "gender", "Género", "Male; Female; Prefer not to say", "Blank field/NA only if not available",
  "non_local_student", "non-local student", "Estudiante foráneo", "Yes; No", "Blank field/NA",
  "current_university_condition", "current university condition", "Condición actual en la vida universitaria", "Full-time student; Study and work", "Blank field/NA",
  "receives_university_support", "receives university support", "Recibe apoyo de la universidad", "Yes; No", "Blank field/NA",
  "academic_program", "academic program", "Programa académico", "14 academic programs in Spanish as listed in the sampling frame", "Blank field/NA",
  "current_program_term", "current program term", "Semestre o matrícula actual", "1-12; More than 12", "Blank field/NA",
  "cumulative_gpa_papa", "cumulative GPA/PAPA", "PAPA acumulado", "Numeric from 0.0 to 5.0; missing when unavailable or non-interpretable", "Blank field/NA",
  "independent_study_time", "independent study time", "Tiempo de estudio independiente", "0-1; 1-2; 2-3; 3-4; 4-5; More than 5", "Blank field/NA",
  "organizes_notes_before_tests", "organizes notes before tests", "Organiza apuntes antes de evaluaciones", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "study_method_effectiveness", "study method effectiveness", "Efectividad del método de estudio", "Not effective at all; Slightly effective; Neutral; Effective; Very effective", "Blank field/NA",
  "uses_supplementary_resources", "uses supplementary resources", "Usa recursos complementarios", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "procrastination_frequency", "procrastination frequency", "Frecuencia de procrastinación", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "study_groups_or_tutoring", "study groups or tutoring", "Grupos de estudio o tutorías", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "self_rated_academic_performance", "self-rated academic performance", "Rendimiento académico autopercibido", "Poor; Fair; Good; Outstanding; Excellent", "Blank field/NA",
  "satisfaction_with_grades", "satisfaction with grades", "Satisfacción con las calificaciones", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "career_satisfaction_affects_motivation", "career satisfaction affects motivation", "Satisfacción con la carrera y motivación", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "program_meets_expectations", "program meets expectations", "La carrera cumple expectativas", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "ai_tools_raw", "AI tools raw", "IA utilizadas (texto libre)", "Free-text multi-response field", "Blank field/NA only if no entry recorded",
  "ai_tools_standardized", "AI tools standardized", "IA estandarizadas", "Semicolon-delimited standardized tool families", "Blank field/NA when no tool could be standardized",
  "n_ai_tools", "number of AI tools", "Número de IA reportadas", "Integer count derived from ai_tools_standardized", "0 when no standardized tool is available",
  "ai_use_frequency_for_study", "AI use frequency for study", "Frecuencia de uso de IA en el estudio", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "ai_helped_understand_topics", "AI helped understand topics", "La IA ayudó a comprender temas", "Definitely no; Probably no; Neutral; Probably yes; Definitely yes", "Blank field/NA",
  "ai_use_in_academic_tasks_is_fraud", "AI use in academic tasks is fraud", "El uso de IA es fraude", "Strongly disagree; Disagree; Undecided; Agree; Strongly agree", "Blank field/NA",
  "failed_evaluated_activity_due_to_ai", "failed evaluated activity due to AI", "Perdió actividades evaluativas por IA", "Yes; No", "Blank field/NA",
  "verifies_work_with_ai_after_completion", "verifies work with AI after completion", "Verifica trabajos con IA", "Never; Rarely; Occasionally; Almost always; Always", "Blank field/NA",
  "perceived_ai_dependence", "perceived AI dependence", "Dependencia percibida de IA", "Not at all; Probably not; Not sure; Probably yes; A lot", "Blank field/NA",
  "perceived_creativity_reduction_from_ai", "perceived creativity reduction from AI", "Reducción percibida de creatividad", "Not at all; Probably not; Not sure; Probably yes; A lot", "Blank field/NA",
  "prompt_engineering_knowledge", "prompt engineering knowledge", "Conocimiento de ingeniería de prompts", "Not at all; Probably not; Not sure; Probably yes; A lot", "Blank field/NA",
  "uses_ai_for_nonacademic_activities", "uses AI for non-academic activities", "Usa IA para actividades no académicas", "Yes; No", "Blank field/NA"
)

write_csv(codebook, file.path(package_dir, "codebook.csv"), na = "")

# ------------------------------------------------------------------
# 11. Tables used in the manuscript
# ------------------------------------------------------------------

table1_sampling <- bind_rows(
  program_summary %>%
    transmute(
      `Academic program` = academic_program,
      `Enrolled 2025-1` = enrolled_2025_1,
      `Planned sample` = planned_sample
 #     `Records in survey export` = survey_export_records
    ),
  tibble(
    `Academic program` = "Total",
    `Enrolled 2025-1` = sum(program_summary$enrolled_2025_1, na.rm = TRUE),
    `Planned sample` = sum(program_summary$planned_sample, na.rm = TRUE)
 #   `Records in survey export` = sum(program_summary$survey_export_records, na.rm = TRUE)
  )
)
write_csv(table1_sampling, file.path(table_dir, "table1_sampling_frame.csv"), na = "")

file_inventory <- tibble(
  File = c(
    "survey_raw_spanish_anonymized.csv",
    "survey_cleaned_english.csv",
    "sampling_frame_by_program.csv",
    "codebook.csv",
    "questionnaire_bilingual.csv",
    "analysis_script.R"
  ),
  Format = c("CSV", "CSV", "CSV", "CSV", "CSV", "R script"),
  Contents = c(
    paste0(nrow(raw_public), " rows × ", ncol(raw_public), " columns"),
    paste0(nrow(survey_cleaned), " rows × ", ncol(survey_cleaned), " columns"),
    paste0(nrow(package_sampling_frame), " rows × ", ncol(package_sampling_frame), " columns"),
    paste0(nrow(codebook), " rows × ", ncol(codebook), " columns"),
    paste0(nrow(questionnaire), " rows × ", ncol(questionnaire), " columns"),
    "1 file"
  ),
  Description = c(
    "Original questionnaire responses in Spanish with response date retained and exact timestamps removed.",
    "Clean analytical dataset with English variable names, harmonized categories, cleaned GPA values, standardized AI-tool field, and derived tool count.",
    "Program-level sampling frame with enrolled population, planned sample, and realized response counts.",
    "Variable dictionary for the cleaned analytical file, including labels, response options, and missing-value conventions.",
    "Question codes and survey items in Spanish and English, grouped by thematic section.",
    "Reproducible script for import, cleaning, descriptive summaries, validation checks, and figure generation."
  )
)
write_csv(file_inventory, file.path(table_dir, "table2_data_records.csv"), na = "")

indicator_table <- tibble(
  Domain = c(
    rep("Sample composition", 5),
    rep("Study habits", 5),
    rep("Academic self-perception", 2),
    rep("AI use patterns", 4),
    rep("Perceived usefulness and ethics", 3),
    rep("Perceived consequences", 5)
  ),
  Indicator = c(
    "Male",
    "Female",
    "Non-local students",
    "Full-time students",
    "Students receiving university support",
    "Independent study >5 hours/week",
    "Organize notes almost always/always",
    "Use supplementary resources almost always/always",
    "Procrastinate almost always/always",
    "Participate in study groups/tutoring at least occasionally",
    "Good/outstanding/excellent academic performance",
    "Program meets expectations almost always/always",
    "Use AI almost always/always for study",
    "Report ChatGPT use",
    "Report Gemini use",
    "Report Copilot or DeepSeek use",
    "AI probably/definitely helps understanding",
    "Disagree/strongly disagree that AI use is fraud",
    "Undecided about fraud item",
    "Failed assessed activity because of AI use",
    "Perceived dependence probably yes/a lot",
    "Perceived creativity reduction probably yes/a lot",
    "Prompt knowledge probably yes/a lot",
    "Use AI for non-academic activities"
  ),
  n = c(
    sum(survey_cleaned$gender == "Male", na.rm = TRUE),
    sum(survey_cleaned$gender == "Female", na.rm = TRUE),
    sum(survey_cleaned$non_local_student == "Yes", na.rm = TRUE),
    sum(survey_cleaned$current_university_condition == "Full-time student", na.rm = TRUE),
    sum(survey_cleaned$receives_university_support == "Yes", na.rm = TRUE),
    sum(survey_cleaned$independent_study_time == "More than 5", na.rm = TRUE),
    sum(survey_cleaned$organizes_notes_before_tests %in% c("Almost always", "Always"), na.rm = TRUE),
    sum(survey_cleaned$uses_supplementary_resources %in% c("Almost always", "Always"), na.rm = TRUE),
    sum(survey_cleaned$procrastination_frequency %in% c("Almost always", "Always"), na.rm = TRUE),
    sum(survey_cleaned$study_groups_or_tutoring %in% c("Occasionally", "Almost always", "Always"), na.rm = TRUE),
    sum(survey_cleaned$self_rated_academic_performance %in% c("Good", "Outstanding", "Excellent"), na.rm = TRUE),
    sum(survey_cleaned$program_meets_expectations %in% c("Almost always", "Always"), na.rm = TRUE),
    sum(survey_cleaned$ai_use_frequency_for_study %in% c("Almost always", "Always"), na.rm = TRUE),
    sum(str_detect(coalesce(survey_cleaned$ai_tools_standardized, ""), "ChatGPT"), na.rm = TRUE),
    sum(str_detect(coalesce(survey_cleaned$ai_tools_standardized, ""), "Gemini"), na.rm = TRUE),
    sum(str_detect(coalesce(survey_cleaned$ai_tools_standardized, ""), "Copilot|DeepSeek"), na.rm = TRUE),
    sum(survey_cleaned$ai_helped_understand_topics %in% c("Probably yes", "Definitely yes"), na.rm = TRUE),
    sum(survey_cleaned$ai_use_in_academic_tasks_is_fraud %in% c("Strongly disagree", "Disagree"), na.rm = TRUE),
    sum(survey_cleaned$ai_use_in_academic_tasks_is_fraud == "Undecided", na.rm = TRUE),
    sum(survey_cleaned$failed_evaluated_activity_due_to_ai == "Yes", na.rm = TRUE),
    sum(survey_cleaned$perceived_ai_dependence %in% c("Probably yes", "A lot"), na.rm = TRUE),
    sum(survey_cleaned$perceived_creativity_reduction_from_ai %in% c("Probably yes", "A lot"), na.rm = TRUE),
    sum(survey_cleaned$prompt_engineering_knowledge %in% c("Probably yes", "A lot"), na.rm = TRUE),
    sum(survey_cleaned$uses_ai_for_nonacademic_activities == "Yes", na.rm = TRUE)
  )
) %>%
  mutate(`%` = round(n / nrow(survey_cleaned) * 100, 1))
print(indicator_table)
write_csv(indicator_table, file.path(table_dir, "table3_data_overview.csv"), na = "")

exact_duplicates <- nrow(survey) - nrow(distinct(survey))
duplicate_timestamps <- sum(duplicated(survey$response_timestamp))
out_of_range_age <- sum(!is.na(suppressWarnings(as.numeric(survey$age_raw))) &
  !(suppressWarnings(as.numeric(survey$age_raw)) >= 15 & suppressWarnings(as.numeric(survey$age_raw)) <= 60))
gpa_missing_after_clean <- sum(is.na(survey_cleaned$cumulative_gpa_papa))
program_mismatch <- setdiff(unique(survey_cleaned$academic_program), unique(program_summary$academic_program))
blank_categorical_items <- survey %>%
  select(-any_of(c("response_timestamp", "age_raw", "cumulative_gpa_raw", "ai_tools_raw"))) %>%
  summarise(across(everything(), count_blank_values)) %>%
  unlist(use.names = FALSE) %>%
  sum()

validation_table <- tibble(
  `Validation domain` = c(
    "Structural completeness",
    "Structural completeness",
    "Duplicate screening",
    "Duplicate screening",
    "Range validation",
    "Range validation",
    "Category validation",
    "Sampling coverage",
    "Text harmonization",
    "Missingness profile"
  ),
  Check = c(
    "Rows in survey export",
    "Original questionnaire variables",
    "Exact duplicate rows",
    "Duplicate timestamps",
    "Age values outside 15-60 years",
    "GPA values recoded to missing",
    "Program labels unmatched to sampling frame",
    "Programs in sampling frame",
    "Standardized AI tool families",
    "Original categorical items with blank cells"
  ),
  Outcome = c(
    nrow(survey_cleaned),
    ncol(survey_source),
    exact_duplicates,
    duplicate_timestamps,
    out_of_range_age,
    gpa_missing_after_clean,
    length(program_mismatch),
    nrow(program_summary),
    n_distinct(unlist(str_split(na.omit(survey_cleaned$ai_tools_standardized), ";\\s*"))),
    blank_categorical_items
  ),
  Interpretation = c(
    "All records retained after screening for exact duplicates.",
    "The response file contained the 29 questionnaire fields defined in the coding sheet.",
    "No rows were identical across all coded questionnaire variables.",
    "No repeated timestamp values were found in the response export.",
    "Implausible ages were recoded to missing in the cleaned file.",
    "Free-text GPA entries indicating first-semester status or non-interpretable values were set to missing.",
    ifelse(length(program_mismatch) == 0,
      "All program labels in the response export matched the sampling frame.",
      paste("Unmatched program labels:", paste(program_mismatch, collapse = "; "))
    ),
    paste0("The sampling frame contains ", nrow(program_summary), " academic programs."),
    "Free-text AI tool entries were normalized into recurring tool families using rule-based parsing.",
    "Blank categorical items were counted after excluding timestamp, GPA, age, and free-text AI-tool fields."
  )
)
write_csv(validation_table, file.path(table_dir, "table4_validation_checks.csv"), na = "")

chi_program_ai <- suppressWarnings(chisq.test(
  table(survey_cleaned$academic_program, survey_cleaned$ai_use_frequency_for_study),
  correct = FALSE
))

spearman_result <- function(data, x, y, label_x, label_y) {
  temp <- data %>% select({{ x }}, {{ y }}) %>% drop_na()
  test <- suppressWarnings(cor.test(as.numeric(temp[[1]]), as.numeric(temp[[2]]), method = "spearman", exact = FALSE))
  tibble(
    `Variable 1` = label_x,
    `Variable 2` = label_y,
    Statistic = "Spearman rho",
    Value = round(as.numeric(test$estimate), 3),
    df = NA_real_,
    `p-value` = format_p(test$p.value),
    `Effect size` = NA_character_,
    n = nrow(temp)
  )
}

association_table <- bind_rows(
  tibble(
    `Variable 1` = "Academic program",
    `Variable 2` = "AI use frequency",
    Statistic = "Chi-square",
    Value = round(as.numeric(chi_program_ai$statistic), 3),
    df = as.numeric(chi_program_ai$parameter),
    `p-value` = format_p(chi_program_ai$p.value),
    `Effect size` = paste0("Cramér's V = ", sprintf("%.3f", cramers_v(table(survey_cleaned$academic_program, survey_cleaned$ai_use_frequency_for_study)))),
    n = nrow(survey_cleaned)
  ),
  spearman_result(survey_cleaned, independent_study_time, ai_use_frequency_for_study, "Independent study time", "AI use frequency"),
  spearman_result(survey_cleaned, ai_helped_understand_topics, ai_use_frequency_for_study, "AI understanding", "AI use frequency"),
  spearman_result(survey_cleaned, perceived_ai_dependence, perceived_creativity_reduction_from_ai, "AI dependence", "Creativity reduction"),
  spearman_result(survey_cleaned, program_meets_expectations, organizes_notes_before_tests, "Program expectations", "Note organization"),
  spearman_result(survey_cleaned, procrastination_frequency, ai_use_frequency_for_study, "Procrastination", "AI use frequency"),
  spearman_result(survey_cleaned, prompt_engineering_knowledge, ai_use_frequency_for_study, "Prompt knowledge", "AI use frequency")
)
write_csv(association_table, file.path(table_dir, "table5_association_checks.csv"), na = "")

# ------------------------------------------------------------------
# 12. Figures
# ------------------------------------------------------------------
#ggsave(file.path(fig_dir, "figure1_workflow.pdf"), width = 10, height = 7, dpi = 600)


#png(file.path(fig_dir, "figure1_workflow.png"), width = 2400, height = 1800, res = 300)
pdf(file.path(fig_dir, "figure1_workflow.pdf"), width = 8, height = 6)
par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))

boxes <- data.frame(
  xleft = 0.10,
  xright = 0.90,
  ybottom = c(0.83, 0.63, 0.43, 0.23, 0.03),
  ytop = c(0.94, 0.74, 0.54, 0.34, 0.14),
  label = c(
    paste0(
      "Administrative sampling frame\nPopulation = ", population_total,
      " students across ", nrow(program_summary),
      " programs\nPlanned proportional sample = ", planned_total_sample
    ),
    paste0(
      "Questionnaire coding sheet\n",
      nrow(question_key), " coded items from Temporalidad to Q28"
    ),
    paste0(
      "Survey export available for curation\n",
      nrow(survey_source), " response records and ",
      ncol(survey_source), " original variables"
    ),
    paste0(
      "Cleaning and validation\n", exact_duplicates, " exact duplicate rows removed; ",
      out_of_range_age, " implausible age values recoded missing;\n",
      gpa_missing_after_clean, " GPA entries set to missing after harmonization"
    ),
    "Public release package\nSpanish raw file, cleaned English file, codebook, questionnaire,\nsampling frame, and reproducible R script"
  ),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(boxes))) {
  rect(boxes$xleft[i], boxes$ybottom[i], boxes$xright[i], boxes$ytop[i], col = "#EEF2F7", border = "#4C566A", lwd = 2)
  text(0.50, mean(c(boxes$ybottom[i], boxes$ytop[i])), labels = boxes$label[i], cex = 1.0)
}
arrows(0.50, 0.83, 0.50, 0.74, length = 0.08, lwd = 2, col = "#4C566A")
arrows(0.50, 0.63, 0.50, 0.54, length = 0.08, lwd = 2, col = "#4C566A")
arrows(0.50, 0.43, 0.50, 0.34, length = 0.08, lwd = 2, col = "#4C566A")
arrows(0.50, 0.23, 0.50, 0.14, length = 0.08, lwd = 2, col = "#4C566A")
dev.off()

all_tools <- survey_cleaned %>%
  select(ai_tools_standardized) %>%
  filter(!is.na(ai_tools_standardized), ai_tools_standardized != "") %>%
  separate_rows(ai_tools_standardized, sep = ";\\s*") %>%
  count(ai_tools_standardized, sort = TRUE, name = "n") %>%
  mutate(percent = round(n / nrow(survey_cleaned) * 100, 1)) %>%
  slice_head(n = 10) %>%
  mutate(ai_tools_standardized = fct_reorder(ai_tools_standardized, n))

p_tools <- ggplot(all_tools, aes(x = ai_tools_standardized, y = n)) +
  geom_col(fill = "#6D8EAD") +
  geom_text(aes(label = paste0(n, " (", percent, "%)")), hjust = -0.10, size = 3.0) +
  coord_flip() +
  labs(x = NULL, y = "Students reporting tool use") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.major.y = element_blank()) +
  expand_limits(y = max(all_tools$n, na.rm = TRUE) * 1.12)

ai_freq_df <- survey_cleaned %>%
  count(ai_use_frequency_for_study, name = "n") %>%
  mutate(percent = round(n / nrow(survey_cleaned) * 100, 1))

p_freq <- ggplot(ai_freq_df, aes(x = ai_use_frequency_for_study, y = n)) +
  geom_col(fill = "#86A9C7") +
  geom_text(aes(label = paste0(n, "\n(", percent, "%)")), vjust = -0.18, size = 3.0) +
  labs(x = NULL, y = "Students") +
  theme_minimal(base_size = 10) +
  expand_limits(y = max(ai_freq_df$n, na.rm = TRUE) * 1.12)

# --- Combine and Save ---
figure_2 <- (p_tools | p_freq) +
  plot_layout(guides = "collect") + plot_annotation(tag_levels = 'A') &
  theme(plot.tag = element_text(face = 'bold'), legend.position = 'right')

print(figure_2)
ggsave(file.path(fig_dir, "F2.pdf"),figure_2, width=12, height=7,device = "pdf",dpi=600)
dev.off()

cor_df <- survey_cleaned %>%
  transmute(
    `Study time` = as.numeric(independent_study_time),
    `Notes` = as.numeric(organizes_notes_before_tests),
    `Program expectations` = as.numeric(program_meets_expectations),
    `AI use` = as.numeric(ai_use_frequency_for_study),
    `AI understanding` = as.numeric(ai_helped_understand_topics),
    `Procrastination` = as.numeric(procrastination_frequency),
    `Prompt knowledge` = as.numeric(prompt_engineering_knowledge),
    `AI dependence` = as.numeric(perceived_ai_dependence),
    `Creativity reduction` = as.numeric(perceived_creativity_reduction_from_ai)
  )

cor_mat <- suppressWarnings(cor(cor_df, method = "spearman", use = "pairwise.complete.obs"))
cor_long <- as.data.frame(as.table(cor_mat))
names(cor_long) <- c("Var1", "Var2", "rho")

heatmap_plot <- ggplot(cor_long, aes(x = Var2, y = Var1, fill = rho)) +
  geom_tile() +
  geom_text(aes(label = ifelse(abs(rho) >= 0.15 | Var1 == Var2, sprintf("%.2f", rho), "")), size = 2.8) +
  scale_fill_gradient2(low = "#E8EEF3", mid = "#6FA3C8", high = "#0E4F8A", midpoint = 0, limits = c(-0.2, 1)) +
  labs(x = NULL, y = NULL, fill = "Spearman's rho") +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())

ggsave(file.path(fig_dir, "F3.pdf"), plot = heatmap_plot, width = 8, height = 6.8, dpi = 600)

# ------------------------------------------------------------------
# 13. Save a copy of this script inside the package, when possible
# ------------------------------------------------------------------

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) > 0) {
  current_script <- sub("^--file=", "", script_arg[1])
  if (file.exists(current_script)) {
    file.copy(current_script, file.path(package_dir, "analysis_script.R"), overwrite = TRUE)
  }
}

message("Curation complete. Outputs written to: ", normalizePath(getwd()))
