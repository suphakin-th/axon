Name:           axon
Version:        1.0.0
Release:        1%{?dist}
Summary:        Universal CI/CD scaffold for GitHub Actions and GitLab CI
License:        MIT
URL:            https://github.com/suphakin-th/axon
BuildArch:      noarch
Requires:       curl

Source0:        axon-%{version}.tar.gz

%description
axon is a universal CI/CD scaffold tool that sets up production-ready
GitHub Actions and GitLab CI pipelines for any language or framework.

Run "axon init" in any project directory to scaffold CI/CD files
immediately. Supports Node.js, Python, Go, PHP, Java, Ruby, .NET,
and any language that can be containerised with Docker.

%prep
%setup -q

%install
mkdir -p %{buildroot}%{_bindir}
install -m 755 bin/axon %{buildroot}%{_bindir}/axon

%files
%license LICENSE
%{_bindir}/axon

%changelog
* Mon Jun 01 2026 suphakin-th <suphakin.th@gmail.com> - 1.0.0-1
- Initial release
