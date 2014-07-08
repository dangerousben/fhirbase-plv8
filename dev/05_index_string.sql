--db:fhirb
--{{{

CREATE OR REPLACE FUNCTION
index_string_complex_type(_path varchar[], _item jsonb)
RETURNS varchar LANGUAGE plpgsql AS $$
DECLARE
  /* el fhir.expanded_resource_elements%rowtype; */
  vals varchar[] := array[]::varchar[];
BEGIN
  -- TODO: implement more reason algorithm
  RETURN _item::text;
END;
$$;

CREATE OR REPLACE FUNCTION
index_string_human_name(v jsonb)
RETURNS varchar LANGUAGE sql AS $$
  WITH strings AS (
  SELECT string_agg(jsonb_array_elements_text, ' ') as s
    FROM jsonb_array_elements_text(v->'family')

  UNION

  SELECT string_agg(jsonb_array_elements_text, ' ') as s
    FROM jsonb_array_elements_text(v->'given')
  )
  SELECT string_agg(s, ' ') FROM strings
$$;

CREATE OR REPLACE FUNCTION
index_string_resource(rsrs jsonb)
RETURNS jsonb[] LANGUAGE plpgsql AS $$
DECLARE
  prm fhir.resource_indexables%rowtype;
  attrs jsonb[];
  item jsonb;
  index_vals varchar[];
  new_val varchar;
  result jsonb[] := array[]::jsonb[];
BEGIN
  FOR prm IN
    SELECT * FROM fhir.resource_indexables
    WHERE resource_type = rsrs->>'resourceType'
    AND search_type = 'string'
    AND array_length(path, 1) > 1
  LOOP
    index_vals := ARRAY[]::varchar[];

    attrs := json_get_in(rsrs, _rest(prm.path));

    IF prm.is_primitive THEN
      index_vals := json_array_to_str_array(attrs);
    ELSE
      FOR item IN SELECT unnest(attrs)
      LOOP
        CASE prm.type
        WHEN 'HumanName' THEN
          new_val := index_string_human_name(item);
        ELSE
          new_val := index_string_complex_type(prm.path, item);
        END CASE;

        index_vals := index_vals || new_val;
      END LOOP;
    END IF;

    IF array_length(index_vals, 1) > 0 THEN
      result := array_append(result, json_build_object('param', prm.param_name, 'value', index_vals)::jsonb);
    END IF;
  END LOOP;

  RETURN result;
END
$$;

CREATE OR REPLACE FUNCTION
_search_string_expression(_table varchar, _param varchar, _type varchar, _modifier varchar, _value varchar)
RETURNS text LANGUAGE sql AS $$
  SELECT CASE
    WHEN _modifier = '' THEN
      quote_ident(_table) || '.value ilike ' || quote_literal('%' || _value || '%')
    WHEN _modifier = 'exact' THEN
      quote_ident(_table) || '.value = ' || quote_literal(_value)
    END;
$$;
--}}}
