# frozen_string_literal: true

module Elido
  # Mixin used by collection-returning resources to surface a
  # uniform `each` / `each_page` iterator regardless of whether the
  # underlying endpoint uses cursor or offset+limit pagination.
  #
  # the API today returns either:
  #
  #   * { "items": [...], "limit": N, "offset": M }            (links/list)
  #   * { "items": [...], "next_cursor": "abc" or null }       (cursor variant)
  #
  # We detect the shape from the response and bump the right param.
  # Resources call `paginate(endpoint_proc, args)` and yield items.
  module Pagination
    DEFAULT_PAGE_SIZE = 100

    # Yields each item across all pages. Used by resource `each`
    # helpers — caller never has to think about cursors.
    #
    #   client.links.each(workspace_id: 7) { |link| ... }
    #
    def paginate(initial_params: {}, page_size: DEFAULT_PAGE_SIZE, &block)
      return enum_for(:paginate, initial_params: initial_params, page_size: page_size) unless block

      cursor = nil
      offset = 0
      params = initial_params.dup
      # Honour the caller's `limit:` as the page size if they gave one;
      # otherwise use the default. This is the chunk we stride by for
      # the offset variant.
      step = params[:limit] || page_size
      params[:limit] = step unless params.key?(:limit)

      loop do
        if cursor
          params[:cursor] = cursor
        else
          params[:offset] = offset if offset.positive?
        end

        page = yield_page(params)
        items = Array(page.is_a?(Hash) ? (page["items"] || page[:items]) : page)
        items.each(&block)

        if page.is_a?(Hash) && (page["next_cursor"] || page[:next_cursor])
          cursor = page["next_cursor"] || page[:next_cursor]
        elsif items.length >= step
          offset += items.length
        else
          break
        end

        # Safety: a degenerate server response (empty items but no
        # cursor end signal) would loop forever. Bail.
        break if items.empty?
      end
    end

    # Resource classes override this to do the actual GET. The
    # `paginate` driver above only knows the param dict; the
    # response shape is consistent enough that we can keep this
    # interface tiny.
    def yield_page(_params)
      raise NotImplementedError, "Including class must implement #yield_page"
    end
  end
end
