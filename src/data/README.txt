============================================================
Dataset: Study habits and artificial intelligence use among 
university students
============================================================

This repository contains the data and supporting materials 
for a survey-based study on study habits and artificial 
intelligence (AI) use among undergraduate students at the 
Manizales campus of a Colombian public university.

The dataset is designed to support reproducible and secondary 
analysis in educational research, particularly in areas related 
to study behavior, AI adoption, academic integrity, and student 
learning practices.

------------------------------------------------------------
1. Repository contents
------------------------------------------------------------

The repository includes the following files:

1) Resultados_encuesta_sobre_habitos_de_estudio_y_uso_de_IA.xlsx
   - Original survey workbook (Spanish)
   - Sheets included:
     • "Respuestas": Raw survey responses
     • "Preguntas": Questionnaire coding (Temporalidad, P1–P28)
     • "Matriculados y Muestras": Population and sampling structure
     • "Muestras": Program-level sample allocation

2) survey_raw_spanish_anonymized.csv
   - Format: CSV
   - Size: 357 rows × 29 columns
   - Description:
     Original questionnaire variables in Spanish.
     The response timestamp has been reduced to date-only information 
     to minimize re-identification risk.

3) survey_cleaned_english.csv
   - Format: CSV
   - Size: 357 rows × 31 columns
   - Description:
     Cleaned analytical dataset with:
     • English variable names
     • Harmonized categorical responses
     • Cleaned GPA variable
     • Standardized AI tool field
     • Derived count of reported AI tools

4) sampling_frame_by_program.csv
   - Format: CSV
   - Size: 14 rows × 4 columns
   - Description:
     Program-level sampling frame including:
     • Enrolled population
     • Planned proportional sample
     • Final number of records per program

5) codebook.csv
   - Format: CSV
   - Size: 31 rows × 5 columns
   - Description:
     Variable dictionary for the cleaned dataset, including:
     • Variable names
     • English labels
     • Spanish reference labels
     • Response options or formats
     • Missing value conventions

6) questionnaire_bilingual.csv
   - Format: CSV
   - Size: 29 rows × 4 columns
   - Description:
     Questionnaire items in Spanish and English, organized by thematic 
     section and linked to coded item identifiers (Temporalidad, Q1–Q28)

7) analysis_script.R
   - Format: R script
   - Description:
     Reproducible script that:
     • Imports the source Excel files
     • Cleans and harmonizes the dataset
     • Generates derived variables
     • Produces summary tables and figures
     • Performs validation checks

------------------------------------------------------------
2. Study design and sampling
------------------------------------------------------------

The dataset is based on a cross-sectional survey administered during 
the first academic term of 2025.

The sampling strategy followed a proportional allocation across 14 
undergraduate programs. Within each program, data collection followed 
a quota-based approach: responses were collected until the target number 
of students for that program was reached.

The final dataset includes 357 observations and preserves the intended 
distribution of the sample across programs.

------------------------------------------------------------
3. Data structure
------------------------------------------------------------

The dataset includes four main types of variables:

• Numeric (e.g., age, GPA, number of AI tools)
• Binary (e.g., yes/no responses)
• Ordinal categorical (e.g., frequency scales, perceptions)
• Text (e.g., raw AI tool responses)

The cleaned dataset preserves item-level responses and does not impose 
composite indices.

------------------------------------------------------------
4. Notes on specific variables
------------------------------------------------------------

• "current_program_term":
  This variable corresponds to the student’s current academic term (semester) 
  and should be interpreted as an ordinal measure of academic progression.

• "ai_tools_raw":
  This is a multi-response free-text field. The cleaned dataset includes 
  both the original text and a standardized version.

------------------------------------------------------------
5. Data use and limitations
------------------------------------------------------------

This dataset is intended for descriptive and exploratory research.

Important considerations:
• Single-campus dataset
• Self-reported responses
• Cross-sectional design

The dataset should not be used to draw causal conclusions.

------------------------------------------------------------
6. Reproducibility
------------------------------------------------------------

All data processing steps are documented in the file:

analysis_script.R

Users can reproduce the cleaned dataset and main outputs by running this script.

------------------------------------------------------------
7. Contact and citation
------------------------------------------------------------

If you use this dataset, please cite the associated Data Descriptor article.

For questions or clarifications, please contact the corresponding author.

Cristian David Correa Álvarez 
Universidad Nacional de Colombia
Email: crdcorreaal@unal.edu.co