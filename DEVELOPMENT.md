# SNS-EXT Development Branch

This is the development branch for experimenting with new features and improvements to the SNS-EXT pipeline.

## Branch Information
- **Branch**: `development`
- **Purpose**: Testing new features, improvements, and experimental changes
- **Base**: `main` branch

## Development Guidelines

### Getting Started
1. Always work in this `development` branch for experimental features
2. Make frequent commits with descriptive messages
3. Test changes thoroughly before merging back to main

### Branch Commands
```bash
# Switch to development branch
git checkout development

# Pull latest changes
git pull origin development

# Create feature branch from development
git checkout -b feature/your-feature-name

# Push changes
git push origin development
```

### Testing New Features
- Test on small datasets first
- Verify conda environment compatibility
- Check LSF job submission on Minerva
- Validate output formats

### Current Development Areas
- [ ] New analysis routes
- [ ] Environment optimization
- [ ] Performance improvements
- [ ] Error handling enhancements

## Notes
- Keep main branch stable
- Document all major changes
- Update README when features are stable
