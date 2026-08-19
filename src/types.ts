// Shapes the R server publishes through reactive_output(). Keep these in step
// with R/server_catalog.R and R/server_views.R.

export interface CatalogStatus {
  state: "ready" | "missing";
  message: string;
  total?: number;
}

export interface CatalogFacets {
  organisms: string[];
  sources: string[];
  total: number;
  max_samples: number;
}

export interface CatalogRow {
  uid: string;
  project: string;
  organism: string;
  file_source: string;
  n_samples: number;
  study_title: string;
}

export interface CatalogPage {
  rows: CatalogRow[];
  matched: number;
  total: number;
  page: number;
  pages: number;
  from: number;
  to: number;
}

export interface StudyLink {
  label: string;
  href: string;
}

export interface StudyDetails {
  uid: string;
  project: string;
  organism: string;
  source: string;
  n_samples: number;
  title: string;
  abstract: string;
  large: boolean;
  links: StudyLink[];
}

export interface LoadStatus {
  status: "initial" | "running" | "success" | "error";
  project?: string;
}

export interface GeneChoice {
  id: string;
  label: string;
}

export type StudyState =
  | { loaded: false }
  | {
      loaded: true;
      project: string;
      organism: string;
      source: string;
      n_samples: number;
      n_genes: number;
      genes: GeneChoice[];
      groups: string[];
    };

export interface MetadataTable {
  columns: string[];
  rows: Record<string, unknown>[];
  truncated: boolean;
  n_rows: number;
}
