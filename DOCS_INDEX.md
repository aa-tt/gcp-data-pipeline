# Documentation Index

Quick navigation to all project documentation.

## 🚀 Getting Started

| Document | Description | When to Read |
|----------|-------------|--------------|
| [README.md](README.md) | Project overview, features, architecture | **Start here** |
| [SETUP.md](SETUP.md) | Complete setup guide with step-by-step instructions | Setting up for first time |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Command cheat sheet | Daily operations |

## 🏗️ Architecture & Design

| Document | Description | When to Read |
|----------|-------------|--------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture, data flow diagrams | Understanding the design |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | File organization, code structure | Navigating the codebase |

## 💻 React UI (NEW)

| Document | Description | When to Read |
|----------|-------------|--------------|
| [REACT_UI_SUMMARY.md](REACT_UI_SUMMARY.md) | Overview of React UI addition | **Start here for UI** |
| [REACT_UI_DEPLOYMENT.md](REACT_UI_DEPLOYMENT.md) | Comprehensive deployment guide | Deploying the UI |
| [REACT_UI_QUICK_REF.md](REACT_UI_QUICK_REF.md) | Quick reference commands | Daily UI operations |
| [react-app/README.md](react-app/README.md) | React app specific docs | Working with React code |
| [react-app/BUILD_DEPLOY.md](react-app/BUILD_DEPLOY.md) | Docker build and deployment | Building containers |

## 💰 Cost & Planning

| Document | Description | When to Read |
|----------|-------------|--------------|
| [COST_ANALYSIS.md](COST_ANALYSIS.md) | Cost estimates and optimization tips | Budget planning |

## 🔐 Security & Access

| Document | Description | When to Read |
|----------|-------------|--------------|
| [PERMISSIONING.md](PERMISSIONING.md) | IAM roles and permissions | Setting up security |

## 🎯 Specific Topics

| Document | Description | When to Read |
|----------|-------------|--------------|
| [SNOWFLAKE_INTEGRATION.md](SNOWFLAKE_INTEGRATION.md) | Integrating with Snowflake | Using Snowflake instead of BigQuery |
| [STREAMING_DATA_SUMMARY.md](STREAMING_DATA_SUMMARY.md) | Real-time streaming setup | Setting up streaming pipelines |
| [SAMPLE_DATA_GUIDE.md](SAMPLE_DATA_GUIDE.md) | Generating and using test data | Testing the pipeline |
| [SCHEMA_FIXES.md](SCHEMA_FIXES.md) | Schema migration and fixes | Troubleshooting schema issues |

## 📊 Summary Documents

| Document | Description | When to Read |
|----------|-------------|--------------|
| [SUMMARY.md](SUMMARY.md) | Complete solution summary | Executive overview |
| [COMPLETION_SUMMARY.md](COMPLETION_SUMMARY.md) | Project completion status | Checking what's done |
| [CONCLUSION.md](CONCLUSION.md) | Final thoughts and recommendations | Project wrap-up |

## 📁 Code Documentation

### Terraform

| Path | Description |
|------|-------------|
| `terraform/main.tf` | Root Terraform configuration |
| `terraform/modules/*/` | Individual resource modules |
| `terraform/README.md` | Terraform-specific guide (if exists) |

### Cloud Functions

| Path | Description |
|------|-------------|
| `functions/data-ingestion/main.py` | HTTP data ingestion function |
| `functions/pubsub-processor/main.py` | Pub/Sub event processor |

### PySpark Jobs

| Path | Description |
|------|-------------|
| `pyspark-jobs/etl_transform.py` | Main ETL transformation job |

### Airflow

| Path | Description |
|------|-------------|
| `airflow-dags/data_pipeline_dag.py` | Orchestration DAG |

### React Application

| Path | Description |
|------|-------------|
| `react-app/src/App.jsx` | Main React component |
| `react-app/Dockerfile` | Container configuration |

## 🛠️ Scripts

| Script | Purpose |
|--------|---------|
| `scripts/deploy.sh` | Deploy entire infrastructure |
| `scripts/deploy-ui.sh` | Deploy React UI only |
| `scripts/test.sh` | Run tests |
| `scripts/cleanup.sh` | Delete all resources |
| `scripts/generate_sample_data.py` | Generate test data |
| `scripts/setup_monitoring.sh` | Set up monitoring |

## 📖 Reading Path by Role

### For Project Managers / Executives
1. [README.md](README.md) - Overview
2. [SUMMARY.md](SUMMARY.md) - Complete summary
3. [COST_ANALYSIS.md](COST_ANALYSIS.md) - Budget
4. [ARCHITECTURE.md](ARCHITECTURE.md) - Design
5. [REACT_UI_SUMMARY.md](REACT_UI_SUMMARY.md) - UI overview

### For DevOps Engineers
1. [SETUP.md](SETUP.md) - Initial setup
2. [REACT_UI_DEPLOYMENT.md](REACT_UI_DEPLOYMENT.md) - UI deployment
3. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Commands
4. [REACT_UI_QUICK_REF.md](REACT_UI_QUICK_REF.md) - UI commands
5. [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - File organization
6. [PERMISSIONING.md](PERMISSIONING.md) - Security setup

### For Data Engineers
1. [ARCHITECTURE.md](ARCHITECTURE.md) - Data flow
2. [SETUP.md](SETUP.md) - Setup guide
3. [SAMPLE_DATA_GUIDE.md](SAMPLE_DATA_GUIDE.md) - Test data
4. [STREAMING_DATA_SUMMARY.md](STREAMING_DATA_SUMMARY.md) - Streaming
5. [SNOWFLAKE_INTEGRATION.md](SNOWFLAKE_INTEGRATION.md) - Snowflake
6. PySpark job code - Transformation logic

### For Frontend Developers
1. [REACT_UI_SUMMARY.md](REACT_UI_SUMMARY.md) - UI overview
2. [react-app/README.md](react-app/README.md) - App docs
3. [react-app/BUILD_DEPLOY.md](react-app/BUILD_DEPLOY.md) - Build guide
4. [REACT_UI_QUICK_REF.md](REACT_UI_QUICK_REF.md) - Quick commands
5. `react-app/src/App.jsx` - Source code

### For Security Engineers
1. [PERMISSIONING.md](PERMISSIONING.md) - IAM setup
2. [SETUP.md](SETUP.md) - Service accounts
3. [REACT_UI_DEPLOYMENT.md](REACT_UI_DEPLOYMENT.md) - UI security
4. Terraform IAM modules - Infrastructure security

## 🔍 Finding Specific Information

### "How do I deploy X?"
- **Infrastructure**: [SETUP.md](SETUP.md)
- **React UI**: [REACT_UI_DEPLOYMENT.md](REACT_UI_DEPLOYMENT.md)
- **Quick deploy**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md) or [REACT_UI_QUICK_REF.md](REACT_UI_QUICK_REF.md)

### "How much will this cost?"
- [COST_ANALYSIS.md](COST_ANALYSIS.md)

### "How does the data flow?"
- [ARCHITECTURE.md](ARCHITECTURE.md)

### "What files do what?"
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

### "How do I test this?"
- [SAMPLE_DATA_GUIDE.md](SAMPLE_DATA_GUIDE.md)
- [SETUP.md](SETUP.md) - Step 7/8

### "How do I fix X?"
- [SCHEMA_FIXES.md](SCHEMA_FIXES.md) - Schema issues
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General issues (if exists)
- Check individual component READMEs

### "What are the command shortcuts?"
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Infrastructure
- [REACT_UI_QUICK_REF.md](REACT_UI_QUICK_REF.md) - UI

## 📝 Document Status

| Status | Document Count | Examples |
|--------|----------------|----------|
| ✅ Complete | 15+ | README, SETUP, ARCHITECTURE, React UI docs |
| 🔄 Living | 5+ | PROJECT_STRUCTURE, QUICK_REFERENCE |
| 📋 Reference | 8+ | All code modules |

## 🔗 External Links

- [GCP Documentation](https://cloud.google.com/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [React Documentation](https://react.dev/)
- [Vite Documentation](https://vitejs.dev/)

## 📄 License

All documentation is covered under the [LICENSE](LICENSE) file in the project root.

---

**Need help?** Start with [README.md](README.md) for an overview, then proceed to [SETUP.md](SETUP.md) for getting started.

**Working with UI?** Jump to [REACT_UI_SUMMARY.md](REACT_UI_SUMMARY.md) for UI-specific documentation.
