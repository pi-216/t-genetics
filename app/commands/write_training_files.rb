# frozen_string_literal: true

class WriteTrainingFiles < ApplicationCommand
  BASE_FOLDER = '/home/tim/source/essdee/EveryDream2trainer/'

  requires :organism

  def call
    organism_hash = organism.to_hsh

    base = JSON.parse(File.read(source_path))
    base['batch_size'] = organism_hash[:batch_size]
    base['clip_skip'] = organism_hash[:clip_skip]
    base['cond_dropout'] = organism_hash[:cond_dropout]
    base['flip_p'] = organism_hash[:flip_p]
    base['grad_accum'] = organism_hash[:grad_accum]
    base['zero_frequency_noise_ratio'] = organism_hash[:zero_frequency_noise_ratio]
    base['optimizer_config'] = optimizer_filename
    base['project_name'] = identifier
    File.write(base_path, base.to_json)

    base = JSON.parse(File.read(optimizer_source_path))
    base['base']['lr'] = organism_hash[:base_lr]
    base['base']['epsilon'] = organism_hash[:base_epsilon]
    base['base']['weight_decay'] = organism_hash[:base_weight_decay]
    base['text_encoder_overrides']['lr'] = organism_hash[:text_lr]
    base['text_encoder_overrides']['epsilon'] = organism_hash[:text_epsilon]
    base['text_encoder_overrides']['weight_decay'] = organism_hash[:text_weight_decay]
    File.write(optimizer_path, base.to_json)
  end

  private

  def identifier
    "#{organism.chromosome.name}_g#{organism.generation.iteration}_o#{organism.id}"
  end

  def source_path
    "#{BASE_FOLDER}tg1gen-source.json"
  end

  def optimizer_source_path
    "#{BASE_FOLDER}optimizer-tg1gen-source.json"
  end

  def base_filename
    "#{identifier}.json"
  end

  def optimizer_filename
    "optimizer_#{identifier}.json"
  end

  def base_path
    [BASE_FOLDER, base_filename].join
  end

  def optimizer_path
    [BASE_FOLDER, optimizer_filename].join
  end
end
