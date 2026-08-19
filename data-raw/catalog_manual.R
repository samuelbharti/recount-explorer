# Curated titles and abstracts for the sources whose metadata files carry no
# study_title and no study_abstract.
#
# Only SRA studies ship those two fields. The other six sources in recount3
# describe one consortium each, so a title generated from the project code plus
# one description for the whole source is both accurate and searchable.
#
# Build time input only. The running app never loads this file.

# The 33 TCGA study codes. Without this a user searching for "melanoma" would
# have to already know that the code is SKCM.
TCGA_STUDY_NAMES <- c(
  ACC = "Adrenocortical carcinoma",
  BLCA = "Bladder urothelial carcinoma",
  BRCA = "Breast invasive carcinoma",
  CESC = "Cervical squamous cell carcinoma and endocervical adenocarcinoma",
  CHOL = "Cholangiocarcinoma",
  COAD = "Colon adenocarcinoma",
  DLBC = "Lymphoid neoplasm diffuse large B-cell lymphoma",
  ESCA = "Esophageal carcinoma",
  GBM = "Glioblastoma multiforme",
  HNSC = "Head and neck squamous cell carcinoma",
  KICH = "Kidney chromophobe",
  KIRC = "Kidney renal clear cell carcinoma",
  KIRP = "Kidney renal papillary cell carcinoma",
  LAML = "Acute myeloid leukemia",
  LGG = "Brain lower grade glioma",
  LIHC = "Liver hepatocellular carcinoma",
  LUAD = "Lung adenocarcinoma",
  LUSC = "Lung squamous cell carcinoma",
  MESO = "Mesothelioma",
  OV = "Ovarian serous cystadenocarcinoma",
  PAAD = "Pancreatic adenocarcinoma",
  PCPG = "Pheochromocytoma and paraganglioma",
  PRAD = "Prostate adenocarcinoma",
  READ = "Rectum adenocarcinoma",
  SARC = "Sarcoma",
  SKCM = "Skin cutaneous melanoma",
  STAD = "Stomach adenocarcinoma",
  TGCT = "Testicular germ cell tumors",
  THCA = "Thyroid carcinoma",
  THYM = "Thymoma",
  UCEC = "Uterine corpus endometrial carcinoma",
  UCS = "Uterine carcinosarcoma",
  UVM = "Uveal melanoma"
)

SOURCE_ABSTRACTS <- c(
  gtex = paste(
    "The Genotype-Tissue Expression (GTEx) project is a public resource for",
    "the study of tissue-specific gene expression and regulation. The project",
    "collected samples from 54 non-diseased tissue sites across nearly 1000",
    "individuals. The assays include whole genome sequencing, whole exome",
    "sequencing, and RNA-seq. See https://gtexportal.org/ for more about GTEx."
  ),
  tcga = paste(
    "The Cancer Genome Atlas (TCGA) characterized more than 20,000 primary",
    "cancer samples and matched normal samples across 33 cancer types. The",
    "National Cancer Institute and the National Human Genome Research",
    "Institute ran the program together from 2006. See",
    "https://www.cancer.gov/ccg/research/genome-sequencing/tcga for more."
  ),
  ANSWER_ALS = paste(
    "Answer ALS is a research program on amyotrophic lateral sclerosis. It",
    "builds induced pluripotent stem cell lines from people with ALS and from",
    "controls, and pairs the molecular data with clinical data. See",
    "https://www.answerals.org/ for more about the program."
  ),
  TARGET_ALS = paste(
    "The Target ALS Human Postmortem Tissue Core provides postmortem central",
    "nervous system tissue from donors with amyotrophic lateral sclerosis and",
    "from controls. The samples cover motor cortex and several levels of the",
    "spinal cord. See https://www.targetals.org/ for more about the program."
  ),
  ega = paste(
    "Data from the European Genome-phenome Archive (EGA), reprocessed by the",
    "recount3 project. EGA holds personally identifiable genetic data and",
    "phenotypic data from biomedical research. See https://ega-archive.org/",
    "for more about the archive."
  ),
  LIBD = paste(
    "Data from the Lieber Institute for Brain Development (LIBD), reprocessed",
    "by the recount3 project. The BrainSeq consortium studies gene expression",
    "in postmortem human brain tissue, mainly the dorsolateral prefrontal",
    "cortex and the hippocampus. See https://www.libd.org/ for more."
  )
)

# Turn a project code into readable words: BLOOD_VESSEL becomes "blood vessel".
humanize_code <- function(x) {
  tolower(gsub("_", " ", x))
}

# The four smallest sources hold ten projects between them, and their codes are
# acronyms that humanize_code() turns into nonsense. BSP1_DLPFC would read
# "bsp1 dlpfc". Name them by hand instead. The key is file_source/project.
PROJECT_TITLES <- c(
  "ega/YOUNG_MICROGLIA_BULK" = "EGA: young microglia, bulk RNA-seq",
  "ega/YOUNG_MICROGLIA_SC" = "EGA: young microglia, single-cell RNA-seq",
  "ega/SPORADIC_ALS_EGAD00001006022" = paste(
    "EGA: sporadic amyotrophic lateral sclerosis",
    "(EGAD00001006022)"
  ),
  "LIBD/BSP1_DLPFC" = "LIBD BrainSeq Phase 1: dorsolateral prefrontal cortex",
  "LIBD/BSP2_DLPFC" = "LIBD BrainSeq Phase 2: dorsolateral prefrontal cortex",
  "LIBD/BSP2_HIPPO" = "LIBD BrainSeq Phase 2: hippocampus",
  "ANSWER_ALS/ANSWER_ALS" = "Answer ALS: first data release",
  "ANSWER_ALS/ANSWER_ALS_V2" = "Answer ALS: data release v2",
  "ANSWER_ALS/ANSWER_ALS_V3" = "Answer ALS: data release v3",
  "ANSWER_ALS/ANSWER_ALS_V5" = "Answer ALS: data release v5"
)

catalog_manual_title <- function(project, file_source) {
  vapply(
    seq_along(project),
    function(i) {
      p <- project[i]
      src <- file_source[i]
      key <- paste0(src, "/", p)
      if (key %in% names(PROJECT_TITLES)) {
        return(unname(PROJECT_TITLES[[key]]))
      }
      if (src == "gtex") {
        if (p == "STUDY_NA") {
          return("GTEx: samples with no assigned tissue")
        }
        return(paste0("GTEx: ", humanize_code(p)))
      }
      if (src == "tcga") {
        name <- TCGA_STUDY_NAMES[[p]]
        return(paste0("TCGA ", p, ": ", name))
      }
      if (src == "TARGET_ALS") {
        return(paste0(
          "Target ALS: ",
          humanize_code(sub("^TALS_", "", p))
        ))
      }
      paste0(src, ": ", humanize_code(p))
    },
    character(1)
  )
}

# One row for each project that needs curated text: uid, title, abstract.
catalog_manual <- function(projects) {
  need <- projects[projects$file_source != "sra", , drop = FALSE]
  if (nrow(need) == 0L) {
    return(NULL)
  }
  abstracts <- unname(SOURCE_ABSTRACTS[need$file_source])
  abstracts[is.na(abstracts)] <- ""
  data.frame(
    uid = catalog_uid(need),
    study_title = catalog_manual_title(need$project, need$file_source),
    study_abstract = abstracts,
    stringsAsFactors = FALSE
  )
}
