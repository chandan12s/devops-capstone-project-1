# AWS Enterprise DevOps Capstone Project (Adapted)

End-to-end DevOps platform demonstrating CI/CD, Infrastructure as Code,
containerization, Kubernetes operations, security, observability,
troubleshooting, and cost optimization — built against a real Node.js
application.

**Adapted from the original AWS EKS-based capstone** to run on a local
Kind cluster instead of EKS (free-tier constraint), while still using
real AWS services (ECR, Secrets Manager, CloudWatch, IAM) where they
have a genuine free tier.

## Project status

- [x] Phase 1: Source Control & Collaboration
- [ ] Phase 2: CI/CD Pipelines
- [ ] Phase 3: Infrastructure as Code
- [ ] Phase 4: Containerization & Kubernetes
- [ ] Phase 5: Observability
- [ ] Phase 6: DevSecOps
- [ ] Phase 7: Troubleshooting
- [ ] Phase 8: Cost Optimization

## Structure

```
devops-capstone/
├── app/                  # Node.js Task API + tests
├── branching-strategy.md # Phase 1 deliverable
└── README.md
```

See [`branching-strategy.md`](./branching-strategy.md) for the Git
workflow used in this project.
