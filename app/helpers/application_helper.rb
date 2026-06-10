module ApplicationHelper
  # Returns the URL only if it has a safe http/https scheme.
  # Prevents javascript: or data: URIs from reaching link_to hrefs.
  def safe_url(url)
    return nil if url.blank?
    uri = URI.parse(url.to_s.strip)
    uri.scheme.in?(%w[ http https ]) ? uri.to_s : nil
  rescue URI::InvalidURIError
    nil
  end
end
