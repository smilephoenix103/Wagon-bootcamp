require 'open-uri'

class ScoresController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    if params[:query].present?
      sql_query = " \
      scores.title ILIKE :query \
      OR composers.name ILIKE :query \ "
    @scores = policy_scope(Score.joins(:composer).where(sql_query, query: "%#{params[:query]}%"))
    authorize @scores
    else
    @scores = policy_scope(Score)
    end
    @composers = Composer.all
  end

  def new
    @collection = Collection.create(title: 'My first collection', user: current_user) if current_user.collections.empty?
    @score = Score.new
    authorize @score
  end

  def create
    @score = Score.new(score_params)
    authorize @score
    #ouvrir le fichier, compter le nb de page depuis le parametre file
    file = open(params[:score][:file])
    reader = PDF::Reader.new(file)

    @score.page_count = reader.page_count

    if @score.save
      ImportScorePagesJob.perform_later(@score)
      redirect_to @score, notice: 'Your score was successfully uploaded.'
    else
      render :new
    end
  end

  def show
    @score = Score.find(params[:id])
    authorize @score
  end

  def viewer
    @score = Score.find(params[:id])
    @page = params[:page_id] ? Page.find(params[:page_id]) : @score.pages.first
    skip_authorization
  end

  private

  def score_params
    params.require(:score).permit(:title, :composer_id, :genre, :score_creation_date, :collection_id, :file)
  end
end
