class PaginatedSerializer < ActiveModel::Serializer::ArraySerializer
  def initialize(resources, options = {})
    options[:meta_key] ||= :pagination
    options[:meta] = {
      current_page: resources.current_page,
      next_page: resources.next_page,
      prev_page: resources.prev_page,
      total_pages: resources.total_pages,
      total_count: resources.total_count
    }
    super(resources, options)
  end
end
