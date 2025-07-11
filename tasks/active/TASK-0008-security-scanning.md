# TASK-0008: Implement Container Security Scanning

## Overview

Add container security scanning to the CI/CD pipeline to identify vulnerabilities in Docker images before deployment. This was temporarily removed due to permission issues with GitHub token.

## Background

The project previously attempted to use Trivy for security scanning but encountered "Resource not accessible by integration" errors when uploading SARIF results to GitHub Security tab. This task aims to properly implement security scanning with correct permissions and configuration.

## Requirements

1. **Vulnerability Scanning**: Scan Docker images for known CVEs and security issues
2. **SARIF Upload**: Upload results to GitHub Security tab for visibility
3. **CI Integration**: Run on all Docker builds (PRs and main branch)
4. **Configurable Severity**: Allow setting minimum severity levels to fail builds
5. **Multiple Scanners**: Consider multiple scanning tools for comprehensive coverage

## Proposed Solution

### Option 1: Fix Trivy Integration (Recommended)
- Configure proper GitHub token permissions for security uploads
- Use Trivy with proper SARIF upload configuration
- Add severity thresholds (e.g., fail on HIGH/CRITICAL)

### Option 2: Alternative Scanners
- **Grype**: Anchore's vulnerability scanner
- **Snyk**: Commercial option with generous free tier
- **Clair**: CoreOS scanner, more complex setup

### Option 3: Registry Scanning
- Use GitHub Container Registry's built-in scanning
- Configure registry-level policies

## Implementation Plan

### Phase 1: Fix GitHub Permissions
1. Research required permissions for SARIF upload
2. Update workflow permissions or use PAT
3. Test with minimal Trivy configuration

### Phase 2: Implement Trivy Properly
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.tags }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'  # Fail on vulnerabilities

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v3
  if: always()  # Upload even if scan fails
  with:
    sarif_file: 'trivy-results.sarif'
    category: 'container-scan'
```

### Phase 3: Add Security Policies
1. Create `.github/security-policy.yml`
2. Define acceptable vulnerability levels
3. Set up notifications for security issues

### Phase 4: Documentation
1. Document security scanning process
2. Add security badge to README
3. Create vulnerability response procedures

## Benefits

1. **Early Detection**: Catch vulnerabilities before production
2. **Compliance**: Meet security requirements for enterprise users
3. **Visibility**: GitHub Security tab integration
4. **Automation**: No manual security reviews needed
5. **Best Practices**: Follow container security standards

## Considerations

1. **False Positives**: May need to maintain ignore lists
2. **Build Time**: Scanning adds 30-60 seconds to builds
3. **Token Permissions**: Requires careful permission management
4. **Base Image Updates**: Need process for updating base images

## Success Criteria

- [ ] Security scanning runs on all Docker builds
- [ ] Results visible in GitHub Security tab
- [ ] No permission errors in CI
- [ ] Documentation for security procedures
- [ ] Configurable severity thresholds

## References

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub SARIF Upload](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github)
- [Container Security Best Practices](https://docs.docker.com/develop/security-best-practices/)

## Notes

- Consider implementing as a separate workflow for better control
- May need to use GitHub App or PAT for proper permissions
- Could add additional scanners in parallel for defense in depth