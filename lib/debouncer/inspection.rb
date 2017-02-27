module Inspection
  def inspect
    '#<%s:0x%014x%s>' % [
        self.class.name,
        object_id << 1,
        inspect_params.map { |k, v| " #{k}: #{v}" }.join
    ]
  end

  def inspect_params
    {}
  end
end
