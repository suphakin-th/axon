class Axon < Formula
  desc "Universal CI/CD scaffold for GitHub Actions and GitLab CI"
  homepage "https://github.com/suphakin-th/axon"
  url "https://github.com/suphakin-th/axon/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "__SHA256__"
  license "MIT"
  head "https://github.com/suphakin-th/axon.git", branch: "main"

  depends_on "curl"

  def install
    bin.install "bin/axon"
  end

  test do
    assert_match "axon v", shell_output("#{bin}/axon version")
  end
end
